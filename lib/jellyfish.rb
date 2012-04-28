require "method_source"
require "jellyfish/ast"
Dir[File.expand_path("../jellyfish/ast/*.rb", __FILE__)].each &method(:require)
require "jellyfish/parser"
require "jellyfish/error"
require "jellyfish/types"
require "jellyfish/symbol_table"
require "jellyfish/compiler"
require "tempfile"
require "thread"

module Jellyfish
  Lock = Mutex.new
  
  def self.method_to_c(meth, lib_name)
    ast = Jellyfish::Parser.new(meth.source).parse
    syms = Jellyfish::SymbolTable.new
    syms.own_method_name = meth.name.to_s
    compiler = Jellyfish::Compiler.new(ast, syms, lib_name)
    compiler.compile
    compiler.c_src
  end
  
  def self.compile_and_require_c(c_src, lib_name, klass)
    file_base = "#{Dir.mktmpdir}/#{lib_name}"
    
    File.open("#{file_base}.c", "w") do |f|
      f.write c_src
    end

    hdrdir = %w(srcdir archdir rubyhdrdir).map { |name|
                RbConfig::CONFIG[name]
              }.find { |dir|
                dir and File.exist? File.join(dir, "/ruby.h")
              }

    cmd = [ RbConfig::CONFIG['LDSHARED'], RbConfig::CONFIG['DLDFLAGS'],
            RbConfig::CONFIG['CCDLFLAGS'], RbConfig::CONFIG['CFLAGS'],
            RbConfig::CONFIG['LDFLAGS'], "-I #{RbConfig::CONFIG['includedir']}",
            "-I #{hdrdir}", "-I #{File.join hdrdir, RbConfig::CONFIG['arch']}",
            "-L#{RbConfig::CONFIG['libdir']}",
            "-o #{file_base}.#{RbConfig::CONFIG["DLEXT"]}",
            "#{file_base}.c"
          ]

    `#{cmd.join " "}`
    
    Lock.synchronize do
      $jellyfish_method_class = klass
      require file_base
      $jellyfish_method_class = nil
    end
  end
end

def jellyfish(meth)
  meth = method(meth) unless meth.respond_to? :source
  uniqid = rand(1e20).to_s(36)
  c_src = Jellyfish.method_to_c(meth, uniqid)
  Jellyfish.compile_and_require_c(c_src, uniqid, meth.owner)
  true
end