jellyfish
=========

ruby&#39;s very own superfast jellyfish

## Example

![shitty benchmark](http://i.imgur.com/NLdAT.png)

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

    N = 36

    puts "Ruby fib(#{N}):"
    puts measure { puts rb_fib N }

    puts "Jellyfish'd fib(#{N}):"
    puts measure { puts c_fib N }

## Features

* It's kinda fast

## Caveats

* Assumes you haven't mucked around with built in methods
* Requires you to declare your parameter and return types
* Really hacky
* Jellyfish has a hacky C extension that can grab the iseq of a method. This makes Ruby really unstable for some reason. Is there a better way to do this?
* It's really really hacky
* It tries to be 'good enough' and sacrifices 100% correctness for speed
* It's a pile of hacks upon hacks
* Don't use it
