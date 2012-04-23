require "jellyfish/jellyfish_ext"
require "jellyfish/error"
require "jellyfish/compiler"
require "tempfile"
require "thread"

Jellyfish::Lock = Mutex.new

def jellyfish(meth)
  meth = method(meth) unless meth.is_a? Method
  raise Jellyfish::Error, "Can't compile variadic methods" if meth.arity < 0
  iseq = Jellyfish.iseq_for_method meth
  compiler = Jellyfish::Compiler.new iseq
  c_src = compiler.compile
  uniqid = rand 1e20
  file_base = "#{Dir.mktmpdir}/#{uniqid}"
  Jellyfish::Lock.synchronize do
    File.open("#{file_base}.c", "w") do |f|
      f.write <<-C
      #include <ruby.h>
      #{c_src}
      void Init_#{uniqid}() {
        const char* method_name = #{meth.name.to_s.inspect};
        int arity = #{meth.arity};
        rb_define_method(rb_gv_get("$jellyfish_method_class"), method_name, jellyfish_function, arity);
      }
      C
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
    $jellyfish_method_class = meth.owner
    require file_base
    $jellyfish_method_class = nil
  end
end