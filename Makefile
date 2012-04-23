ext/jellyfish/jellyfish_ext.bundle: ext/jellyfish/Makefile ext/jellyfish/*.c
	cd ext/jellyfish && make

ext/jellyfish/Makefile: ext/jellyfish/extconf.rb
	cd ext/jellyfish && ruby extconf.rb

clean:
	cd ext/jellyfish && rm -f *.o && rm -f *.bundle && rm -f *.so && rm Makefile