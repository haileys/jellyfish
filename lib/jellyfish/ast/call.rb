module Jellyfish::AST
  class Call < Base
    attr_accessor :receiver, :name, :args
    
    def type(symbols)
      if receiver.is_a? Self and name == symbols.own_method_name
        symbols.returns || Jellyfish::Types::SelfRecursion.new
      else
        Jellyfish::Types[:VALUE]
      end
    end
  end
end