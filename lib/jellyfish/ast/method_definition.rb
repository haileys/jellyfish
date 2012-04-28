module Jellyfish::AST
  class MethodDefinition < Base
    attr_accessor :name, :args, :body
    
    def type(symbols)
      @type ||= body.type(symbols)
    end
  end
end