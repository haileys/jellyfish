module Jellyfish::AST
  class Hash < Base
    attr_accessor :pairs
    
    def type(symbols)
      Jellyfish::Types[:VALUE] # @TODO - maybe Hash?
    end
  end
end