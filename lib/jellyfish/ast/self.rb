module Jellyfish::AST
  class Self < Base
    def type(symbols)
      Types[:VALUE]
    end
  end
end