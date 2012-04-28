module Jellyfish::AST
  class Symbol < Base
    attr_accessor :name
    
    def type(symbols)
      Jellyfish::Types[:VALUE] # @TODO - maybe Symbol?
    end
  end
end