module Jellyfish
  module Types
    class Type
      def convert_to(type)
        type.convert_from self
      end
      
      def common_type(type)
        if type == self
          self
        else
          TYPES[:VALUE]
        end
      end
    end
    
    class Value < Type
      def ctype
        "VALUE"
      end
      
      def convert_from(type)
        case type
        when Value;   "%s"
        when Integer; "INT2FIX(%s)"
        when Boolean; "%s ? Qtrue : Qfalse"
        end
      end
    end
    
    class Integer < Type
      def ctype
        "int"
      end
      
      def convert_from(type)
        case type
        when Value;   "FIX2INT(%s)"
        when Integer; "%s"
        when Boolean; raise Jellyfish::Error, "Can't convert from Boolean to Integer"
        end
      end
    end
    
    class Boolean < Type
      def ctype
        "bool"
      end
      
      def convert_from(type)
        case type
        when Value;   "RTEST(%s) ? true : false"
        when Integer; "true"
        when Boolean; "%s"
        end
      end
    end
    
    class SelfRecursion < Value
      # this is a special type which is returned from recursive calls.
      # it's used to make this work as expected:
      # 
      #   def fact(n)
      #     if n == 1
      #       1
      #     else
      #       n * fact(n - 1)
      #     end
      #   end
      # 
      # the type inferencer will look at 'Integer * SelfRecursion' and figure
      # that the type should probably be Integer
      
      def common_type(type)
        type
      end
    end
    
    TYPES = {
      VALUE:  Value.new,
      int:    Integer.new,
      bool:   Boolean.new
    }
    
    def self.[](type)
      TYPES[type]
    end
  end
end