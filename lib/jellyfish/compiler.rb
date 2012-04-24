module Jellyfish
  class Compiler
    attr_reader :iseq, :opcodes
  
    def initialize(iseq, own_method_name)
      @iseq = iseq.to_a
      @opcodes = @iseq[13]
      @num_locals = 0
      @own_method_name = own_method_name
    end
  
    def compile
      @pseudostack = Hash.new { |h,k| h[k] = [] }
      @symbols = Hash.new { |h,k| if k.nil? then pry binding else h[k] = :VALUE end }
      @is_self = {}
      @locals = {}
      @src = ""
      @stack = []
      @branch_stack_pointers = {}
      find_type_signature
      @opcodes.each do |opcode|
        if opcode.is_a? Fixnum
          output "// line #{opcode}"
          next
        end
        if opcode.is_a? Symbol
          if @branch_stack_pointers[opcode]
            while @stack.size > @branch_stack_pointers[opcode]
              pop
            end
          end
          output "#{opcode}:"
          next
        end
        meth = "op_#{opcode[0]}"
        if respond_to? meth, true
          send meth, *opcode[1..-1]
        else
          require "pry"
          pry binding
          raise Jellyfish::Error, "no compiler for opcode '#{opcode[0]}'"
        end
      end
      "".tap do |src|
        src << "static #{@return_type || :VALUE} fn(VALUE self#{1.upto(@iseq[4][:arg_size]).map { |i| ", #{@locals[2 + @iseq[4][:arg_size] - i]} arg_#{i}" }.join}) {\n"
        @symbols.each do |name, type|
          src << "#{type} #{name};\n"
        end
        1.upto(@iseq[4][:local_size]) do |i|
          src << "#{@locals[i] ||= :VALUE} local_#{i};\n"
        end
        1.upto(@iseq[4][:arg_size]) do |i|
          local_idx = 2 + @iseq[4][:arg_size] - i
          src << "local_#{local_idx} = arg_#{i};\n"
        end
        src << @src << "}\n"
        
        src << "static VALUE rb_fn(VALUE self#{1.upto(@iseq[4][:arg_size]).map { |i| ", VALUE arg_#{i}" }.join}) {\n"
        src << "#{@return_type || :VALUE} retn = fn(self"
        1.upto(@iseq[4][:arg_size]) do |i|
          local_idx = 2 + @iseq[4][:arg_size] - i
          case @locals[local_idx]
          when :VALUE;  src << ", arg_#{i}"
          when :int;    src << ", FIX2INT(arg_#{i})"
          when :bool;   src << ", RTEST(arg_#{i}) ? true : false"
          end
        end
        src << ");\n"
        case @return_type || :VALUE
        when :int;    src << "return INT2FIX(retn);\n"
        when :bool;   src << "return retn ? Qtrue : Qfalse;\n"
        when :VALUE;  src << "return retn;\n"
        end
        src << "}"
      end
    end
  
  private  
    def find_type_signature
      idx = @opcodes.each_with_index.select { |x| x.is_a? Array }
          .find { |op,idx| op[0] == :send and op[1] == :types }[1]
      sl = @opcodes[1...idx].reject { |op,*| op == :trace }
      if sl[0][0] != :putself or sl[-1][0] != :newhash
        raise Jellyfish::Error, "Missing type signature"
      end
      valid_types = [:VALUE, :int, :bool]
      sl[1...-1].each_slice(2) do |a,b|
        raise Jellyfish::Error, "Unknown type '#{b[1]}'" unless valid_types.include? b[1]
        if a[1] == :returns
          @return_type = b[1]
        else
          @locals[a[1]] = b[1]
        end
      end
      @opcodes = @opcodes[(idx+1)..-1]
    end
  
    def output(line)
      @src << "// STACK: #{@stack.inspect}\n"
      @src << "#{line}\n"
    end
  
    def push(type)
      slot = @pseudostack[type].find { |name,available| available }
      if slot
        slot[1] = false
        @stack.push slot[0]
        slot[0]
      else
        name = "st_#{@symbols.count}"
        @pseudostack[type] << [name, false]
        @symbols[name] = type
        @stack.push name
        name
      end
    end
  
    def pop
      return unless @stack.any?
      @stack.pop.tap do |name|
        @pseudostack[@symbols[name]].find { |n,*| n == name }[1] = true
        @is_self.delete name
      end
    end
    
    def stack_element_is_self?(el = 1)
      @is_self[@stack[-el]]
    end

    def op_trace(*)
      #
    end
  
    def op_getlocal(slot)
      output "#{push(@locals[slot] ||= :VALUE)} = local_#{slot};"
    end
    
    def op_leave(*)
      slot = pop
      if @return_type != @symbols[slot]
        require "pry"
        pry binding
        raise Jellyfish::Error, "returning incorrect type (expected #{@return_type}, got #{@symbols[slot]})"
      end
      
      if @return_type == :VALUE
        case @symbols[slot]
        when :int;    output "return INT2FIX(#{slot});"
        when :bool;   output "return #{slot} ? Qtrue : Qfalse;"
        when :VALUE;  output "return #{slot};"
        else
          pry binding
        end
      else
        output "return #{slot};"
      end
    end
    
    { plus: "+", minus: "-" }.each do |name,op|
      define_method "op_opt_#{name}" do |*|
        b = pop
        a = pop
        if @symbols[a] == :int and @symbols[b] == :int
          output "#{push :int} = #{a} #{op} #{b};"
        else
          output "#{push :VALUE} = rb_funcall(#{a}, rb_intern(\"#{op}\"), 1, #{b});"
        end
      end
    end
    
    def op_opt_le(*)
      b = pop
      a = pop
      if @symbols[a] == :int and @symbols[b] == :int
        output "#{push :bool} = (#{a} <= #{b});"
      else
        output "#{push :VALUE} = rb_funcall(#{a}, rb_intern(\"<=\"), 1, #{b});"
      end
    end
    
    def op_pop
      pop
    end
    
    def op_putobject(obj)
      case obj
      when Fixnum;  output "#{push :int} = #{obj};"
      else pry binding
      end
    end
    
    def op_branchunless(lbl)
      slot = pop
      case @symbols[slot]
      when :int;    output "goto #{lbl};"
      when :bool;   output "if(!#{slot}) goto #{lbl};"
      when :VALUE;  output "if(!RTEST(#{slot})) goto #{lbl};"
      else
        pry binding
      end
      @branch_stack_pointers[lbl] = @stack.size
    end
    
    def op_jump(lbl)
      output "goto #{lbl};"
    end
    
    def op_putself
      slot = push :VALUE
      @is_self[slot] = true
      output "#{slot} = self;"
    end
    
    def op_send(meth, arity, *args)
      if stack_element_is_self?(arity + 1) and meth == @own_method_name
        if arity != @iseq[4][:arg_size]
          raise Banana::Error, "calling self with incorrect argument length"
        end
        arg_types = 1.upto(@iseq[4][:arg_size]).map { |i| @locals[2 + @iseq[4][:arg_size] - i]}
        if @stack[-arity..-1].map { |x| @symbols[x] } != arg_types
          raise Banana::Error, "calling self with invalid types"
        end
        call_args = arity.times.map { pop }
        pop # pop self
        output "#{push @return_type} = fn(self, #{call_args.reverse.join ", "});"
      else
        #
      end
    end
  end
end