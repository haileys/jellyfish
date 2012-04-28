module Jellyfish
  class Compiler
    attr_reader :c_src, :ast, :syms
    
    def initialize(ast, syms, ext_name)
      @ast = ast
      @syms = syms
      @ext_name = ext_name
    end
    
    def compile
      @temp_vars = []
      @interned = {}
      @variables = {}
      @stack = []
      @c_src = ""
      @indent = 0
      # look for type declaration:
      if @ast.is_a? AST::MethodDefinition and @ast.body.stmts.first.is_a? AST::Call
        call = @ast.body.stmts.first
        if call.receiver.is_a? AST::Self and call.name == "types"
          # found it!
          unless call.args.size == 1 and call.args[0].is_a? AST::Hash
            error! "argument to 'types' must be a Hash"
          end
          call.args[0].pairs.each do |key,value|
            error! "type must be a symbol" unless value.is_a? AST::Symbol
            case key
            when AST::Variable; syms[key.name] = Types[value.name.intern]
            when AST::Symbol
              if key.name == "returns"
                syms.returns = Types[value.name.intern]
              else
                error! "Unknown variable in type declaration"
              end
            else
              error! "Unknown variable in type declaration"
            end
          end
        end
      end
      compile_node @ast, nil
    end
    
  private
    def error!(message)
      raise Jellyfish::Error, message
    end
  
    def type_of(obj)
      obj.class.name.split("::").last.intern
    end
  
    def temp_var(type)
      n = @temp_vars.size
      @temp_vars << type
      "$#{n}"
    end
    
    def intern_symbol(symbol)
      @interned[symbol.to_s] ||= "sym_#{@interned.count}"
    end
    
    def output(line)
      c_src << "#{"    " * @indent}#{line}\n"
    end
    
    def indent
      @indent += 1
      yield
    ensure
      @indent -= 1
    end
  
    def node
      @stack.last[0]
    end
    
    def return_var
      @stack.last[1]
    end
  
    def compile_node(node, return_in)
      @stack << [node, return_in]
      send type_of(node)
      @stack.pop
    end
    
    def MethodDefinition
      return_type = node.type syms
      return_var = temp_var return_type
      indent do
        compile_node node.body, return_var
        output "return #{return_var};"
      end
      inner_src, @c_src = @c_src, ""
      c_args = node.args.map { |arg| ", #{syms[arg].ctype} #{arg}" }
      
      output "#include <ruby.h>"
      output "#include <stdlib.h>"
      output "#include <stdbool.h>"
      output "#include <math.h>"
      
      if @interned.any?
        output "ID #{@interned.values.join ", "};"
      end
      
      output "static #{return_type.ctype} fn(VALUE self#{c_args.join})"
      output "{"
      indent do
        @temp_vars.each_with_index.group_by(&:first).each do |type, vars|
          output "#{type.ctype} #{vars.map { |v| "$#{v[1]}" }.join ", "};"
        end
      end
      output inner_src
      output "}"
      
      output "static VALUE rb_fn(VALUE self#{node.args.map { |arg| ", VALUE #{arg}" }.join})"
      output "{"
      indent do
        fmt = return_type.convert_to(Types[:VALUE])
        arg_list = ""
        node.args.each do |arg|
          arg_list << ", "
          arg_list << sprintf(syms[arg].convert_from(Types[:VALUE]), arg)
        end
        output "#{return_type.ctype} retn = fn(self#{arg_list});"
        output sprintf("return #{fmt};", "retn")
      end
      output "}"
      
      output "void Init_#{@ext_name}()"
      output "{"
      indent do
        @interned.each do |sym, var|
          output "#{var} = rb_intern(\"#{sym}\");"
        end
        output "rb_define_method(rb_gv_get(\"$jellyfish_method_class\"), #{syms.own_method_name.to_s.inspect}, rb_fn, #{node.args.size});"
      end
      output "}"
    end
    
    def Body
      *init, last = node.stmts
      init.each { |x| compile_node x, nil }
      compile_node last, return_var
    end
    
    { Addition: :+, Subtraction: :-, Multiplication: :*, Division: :/ }.each do |name, oper|
      define_method name do
        fmt = return_var ? "#{return_var} = %s;" : "(void)(%s);"
        left = node.left.type syms
        right = node.right.type syms
        common = left.common_type right
        lvar = temp_var left
        rvar = temp_var right
        case common
        when Types[:VALUE]; expr = "rb_funcall(#{left.convert_to common}, #{intern_symbol oper}, 1, #{right.convert_to common})"
        when Types[:int];   expr = "#{left.convert_to common} #{oper} #{right.convert_to common}"
        else error! "unknown type in #{name.downcase}: #{common.ctype}"
        end
        compile_node node.left, lvar
        compile_node node.right, rvar
        output sprintf(sprintf(fmt, expr), lvar, rvar)
      end
    end
    
    { Equality: :==, Inequality: :!=, LessThan: :<, LessThanEquals: :<=, GreaterThan: :>, GreaterThanEquals: :>= }.each do |name,oper|
      define_method name do
        fmt = return_var ? "#{return_var} = %s;" : "(void)(%s);"
        eq_type = node.type syms
        left = node.left.type syms
        right = node.right.type syms
        lvar = temp_var left
        rvar = temp_var right
        case eq_type
        when Types[:VALUE]; expr = "rb_funcall(#{left.convert_to eq_type}, #{intern_symbol oper}, 1, #{right.convert_to eq_type})"
        when Types[:bool];  expr = "(%s #{oper} %s)"
        else error! "unknown type in addition: #{eq_type.ctype}"
        end
        compile_node node.left, lvar
        compile_node node.right, rvar
        output sprintf(sprintf(fmt, expr), lvar, rvar)
      end
    end
    
    def Variable
      @variables[node.name] = true
      output "#{return_var} = #{node.name};" if return_var
    end
    
    def Call
      if node.receiver.is_a? AST::Self and node.name == "types"
        # this is a type declaration, ignore
      elsif node.receiver.is_a? AST::Self and node.name == syms.own_method_name
        # self recursion
        unless @ast.args.size == node.args.size
          error! "Wrong number of arguments in self recursion"
        end
        call_arg_types = node.args.map { |a| a.type syms }
        meth_arg_types = @ast.args.map { |a| syms[a] }
        temp_vars = call_arg_types.map { |t| temp_var t }
        node.args.zip(temp_vars).each { |arg,var| compile_node arg, var }
        args = ["self"] + temp_vars.each_with_index { |v,i| sprintf call_arg_types[i].convert_to(meth_arg_types[i]), v }
        if return_var
          output "#{return_var} = fn(#{args.join ", "});"
        else
          output "fn(#{args.join ", "});"
        end
      else
        pry binding
      end
    end
    
    def Integer
      if return_var
        output "#{return_var} = #{node.int};"
      end
    end
    
    def If
      if_type = node.type syms
      cond_type = node.cond.type syms
      cond_var = temp_var cond_type
      compile_node node.cond, cond_var
      output "if(#{sprintf cond_type.convert_to(Types[:bool]), cond_var}) {"
      indent do
        *init, last = node.then_stmts
        init.each do |stmt|
          compile_node stmt, nil
        end
        if return_var
          then_type = last.type syms
          then_type = if_type if then_type.is_a? Types::SelfRecursion
          then_var = temp_var then_type
          compile_node last, then_var
          output "#{return_var} = #{sprintf then_type.convert_to(if_type), then_var};"
        else
          compile_node node.then_stmts, nil
        end
      end
      output "} else {"
      indent do
        if node.else_stmts
          *init, last = node.else_stmts
          init.each do |stmt|
            compile_node stmt, nil
          end
          if return_var
            else_type = last.type syms
            else_type = if_type if else_type.is_a? Types::SelfRecursion
            else_var = temp_var else_type
            compile_node last, else_var
            output "#{return_var} = #{sprintf else_type.convert_to(if_type), else_var};"
          else
            compile_node node.then_stmts, nil
          end
        end
      end
      output "}"
    end
  end
end