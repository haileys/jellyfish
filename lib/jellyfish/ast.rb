module Jellyfish
  module AST
    class Base
      def initialize(hash = {})
        hash.each do |k,v|
          send "#{k}=", v
        end
      end
    end
  end
end