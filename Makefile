
HTML := nim-memory.html nim-arc.html

all: $(HTML)

%.html: %.md style.css
	asciidoctor $<

clean:
	rm -f $(HTML)

pub: nim-memory.html
	scp nim-memory.html style.css ico@pruts.nl:/home/ico/websites/www.zevv.nl/nim-memory

lazy-bastard:
	@while true; do sleep 0.5; make; done
