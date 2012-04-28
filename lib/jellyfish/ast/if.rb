module Jellyfish::AST
  class If < Base
    attr_accessor :cond, :then_stmts, :else_stmts
    
    def type(symbols)
      @type ||= begin
        then_type = then_stmts.last.type(symbols)
        if else_stmts
          else_type = else_stmts.last.type(symbols)
          then_type.common_type(else_type)
        else
          then_type
        end
      end
    end
  end
end