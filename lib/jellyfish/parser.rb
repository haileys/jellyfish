require "ripper"

module Jellyfish
  class Parser
    def initialize(source)
      source = Ripper.sexp source unless source.is_a? Array
      raise Error, "syntax error" unless source and source[0] == :program
      @sexp = source[1][0]
    end
    
    def parse
      transform_node @sexp
    end
    
    def transform_node(node)
      send "s_#{node[0]}", *node[1..-1]
    rescue Jellyfish::Error => e
      unless e.message.include? "at line"
        if node.last.is_a? Array and node.last.size == 2 and node.last.count { |x| x.is_a? Fixnum } == 2
          e.message << " at line #{node.last[0]}, col #{node.last[1]}"
        end
      end
      raise e
    end
    
    def error!(message)
      raise Jellyfish::Error, message
    end
    
    def assert!(&bk)
      raise Jellyfish::Error, "Jellyfish bug: #{bk.source}" unless yield
    end
    
    def s_def(name, params, body)
      assert! { name[0] == :@ident }
      AST::MethodDefinition.new(name: name[1], args: []).tap do |method|
        error! "Variadic methods not supported" if params[1].drop(2).any?
        params[1][1].each do |type,name,*|
          assert! { type == :@ident }
          method.args << name
        end
        method.body = transform_node body
      end
    end
    
    def s_bodystmt(body_stmts, rescue_stmts, else_stmts, ensure_stmts)
      if rescue_stmts or else_stmts or ensure_stmts
        error! "rescue/else/ensure is not supported yet"
      end
      AST::Body.new stmts: body_stmts.map(&method(:transform_node))
    end
    
    BINARY_OPERATORS = {
      :+  => AST::Addition,
      :-  => AST::Subtraction,
      :*  => AST::Multiplication,
      :/  => AST::Division,
      :== => AST::Equality,
      :!= => AST::Inequality,
      :>  => AST::GreaterThan,
      :>= => AST::GreaterThanEquals,
      :<  => AST::LessThan,
      :<= => AST::LessThanEquals
    }
    
    def s_binary(left, oper, right)
      klass = BINARY_OPERATORS[oper] or error! "Unsupported binary operator #{oper}"
      klass.new left: transform_node(left), right: transform_node(right)
    end
    
    def s_var_ref(*wtf)
      assert! { wtf.size == 1 }
      type, name = wtf[0]
      assert! { type == :@ident }
      AST::Variable.new name: name
    end
    
    def s_command(name, args)
      AST::Call.new(receiver: AST::Self.new, name: name[1], args: []).tap do |call|
        assert! { args[0] == :args_add_block }
        error! "Calling methods with blocks not currently supported" if args[2]
        args[1].each do |arg|
          call.args << transform_node(arg)
        end
      end
    end
    
    def s_bare_assoc_hash(pairs)
      AST::Hash.new(pairs: []).tap do |hash|
        pairs.each do |type,key,value|
          assert! { type == :assoc_new }
          hash.pairs << [transform_node(key), transform_node(value)]
        end
      end
    end
    
    def s_symbol_literal(node)
      assert! { node[0] == :symbol }
      assert! { [:@ident, :@const].include? node[1][0] }
      AST::Symbol.new name: node[1][1]
    end
    
    define_method "s_@int" do |str,*|
      AST::Integer.new int: str.to_i
    end
    
    def s_if(cond, then_stmts, else_stmts)
      AST::If.new(cond: transform_node(cond), then_stmts: [], else_stmts: else_stmts && []).tap do |node|
        then_stmts.each do |n|
          node.then_stmts << transform_node(n)
        end
        if else_stmts
          assert! { else_stmts[0] == :else }
          else_stmts[1].each do |n|
            node.else_stmts << transform_node(n)
          end
        end
      end
    end
    
    def s_method_add_arg(method, args)
      assert! { method[0] == :fcall }
      AST::Call.new(receiver: AST::Self.new, name: method[1][1], args: []).tap do |call|
        args = args[1]
        assert! { args[0] == :args_add_block }
        error! "Calling methods with blocks not currently supported" if args[2]
        args[1].each do |arg|
          call.args << transform_node(arg)
        end
      end
    end
  end
end