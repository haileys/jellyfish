module Jellyfish::AST
  class Body < Base
    attr_accessor :stmts
    
    def type(symbols)
      @type ||= stmts.last.type(symbols)
    end
  end
end