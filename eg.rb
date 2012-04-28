$: << File.expand_path("../lib/", __FILE__)
$: << File.expand_path("../ext/", __FILE__)
require "jellyfish"
require "pry"
require "coderay"

def rb_fib(n)
  if n <= 2
    1
  else
    rb_fib(n - 1) + rb_fib(n - 2)
  end
end

def c_fib(n) types n => :int, :returns => :int
  if n <= 2
    1
  else
    c_fib(n - 1) + c_fib(n - 2)
  end
end
jellyfish :c_fib

require "benchmark"
include Benchmark

N = 38

puts "Ruby fib(#{N}):"
puts measure { puts rb_fib N }

puts "Jellyfish'd fib(#{N}):"
puts measure { puts c_fib N }

=begin
def fact(n) types n => :int, :returns => :int
  if n == 1
    1
  else
    n * fact(n - 1)
  end
end

if ARGV.include? "src"
  puts CodeRay.scan(Jellyfish.method_to_c(method(:fact), "fact"), :c).terminal
else
  jellyfish :fact
  puts fact(5)
end
=end
