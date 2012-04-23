module Jellyfish
  class Compiler
    attr_reader :iseq, :opcodes
  
    def initialize(iseq)
      @iseq = iseq.to_a
      @opcodes = @iseq[13]
      @num_locals = 0
    end
  
    def compile
      @pseudostack = Hash.new { |h,k| h[k] = [] }
      @symbols = Hash.new { |h,k| if k.nil? then pry binding else h[k] = :VALUE end }
      @locals = {}
      @src = ""
      @stack = []
      find_type_signature
      @opcodes.each do |opcode|
        if opcode.is_a? Fixnum
          output "// line #{opcode}"
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
      "static VALUE Jellyfish_function(VALUE self#{1.upto(@iseq[4][:arg_size]).map { |i| ", VALUE arg_#{i}" }.join}) {\n".tap do |src|
        @symbols.each do |name, type|
          src << "#{type} #{name};\n"
        end
        1.upto(@iseq[4][:local_size]) do |i|
          src << "#{@locals[i] ||= :VALUE} local_#{i};\n"
        end
        1.upto(@iseq[4][:arg_size]) do |i|
          local_idx = 2 + @iseq[4][:arg_size] - i
          case @locals[local_idx]
          when :VALUE;  src << "local_#{local_idx} = arg_#{i};\n"
          when :int;    src << "local_#{local_idx} = FIX2INT(arg_#{i});\n"
          end
        end
        src << @src << "}\n"
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
      valid_types = [:VALUE, :int]
      sl[1...-1].each_slice(2) do |a,b|
        raise Jellyfish::Error, "Unknown type '#{b[1]}'" unless valid_types.include? b[1]
        @locals[a[1]] = b[1]
      end
      @opcodes = @opcodes[(idx+1)..-1]
    end
  
    def output(line)
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
      end
    end

    def op_trace(*)
      #
    end
  
    def op_getlocal(slot)
      output "#{push(@locals[slot] ||= :VALUE)} = local_#{slot};"
    end
    
    def op_leave(*)
      slot = pop
      case @symbols[slot]
      when :int;    output "return INT2FIX(#{slot});"
      when :VALUE;  output "return #{slot};"
      else
        pry binding
      end
    end
    
    def op_opt_plus(*args)
      b = pop
      a = pop
      if @symbols[a] == :int and @symbols[b] == :int
        output "#{push :int} = #{a} + #{b};"
      else
        output "#{push :VALUE} = rb_funcall(#{a}, rb_intern(\"+\"), 1, #{b});"
      end
    end
    
    def op_pop
      pop
    end
  end
end