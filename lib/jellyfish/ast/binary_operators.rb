module Jellyfish::AST
  %w(Addition Subtraction Multiplication Division).each do |klass|
    const_set klass, Class.new(Base) {
      attr_accessor :left, :right
      
      def type(symbols)
        @type ||= left.type(symbols).common_type(right.type(symbols))
      end
    }
  end
  
  %w(Equality Inequality LessThan LessThanEquals GreaterThan GreaterThanEquals).each do |klass|
    const_set klass, Class.new(Base) {
      attr_accessor :left, :right
      
      def type(symbols)
        @type ||= begin
          lt = left.type(symbols)
          if lt.is_a? Jellyfish::Types::Integer
            Jellyfish::Types[:bool]
          else
            lt.common_type(right.type(symbols))
          end
        end
      end
    }
  end
end