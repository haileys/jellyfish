module Jellyfish::AST
  class Integer < Base
    attr_accessor :int
    
    def type(symbols)
      Jellyfish::Types[:int]
    end
  end
end