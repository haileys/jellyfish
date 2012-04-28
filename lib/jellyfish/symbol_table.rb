module Jellyfish
  class SymbolTable
    attr_reader :symbols
    attr_accessor :own_method_name, :returns
    
    def initialize(symbols = {})
      @symbols = symbols
    end
    
    def declared?(sym)
      symbols.key? sym
    end
    
    def [](sym)
      symbols[sym] ||= Types[:VALUE]
    end
    
    def []=(sym, type)
      if symbols[sym] and symbols[sym] != type
        raise Jellyfish::Error, "Type mismatch, attempted to redeclare #{sym} as #{type.ctype}, where previously it was declared as #{symbols[sym].ctype}"
      end
      symbols[sym] = type
    end
  end
end