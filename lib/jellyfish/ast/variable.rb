module Jellyfish::AST
  class Variable < Base
    attr_accessor :name
    
    def type(symbols)
      @type ||= symbols[name]
    end
  end
end