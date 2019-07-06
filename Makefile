
nim-memory.html: nim-memory.md style.css
	asciidoctor nim-memory.md

clean:
	rm -f nim-memory.html

pub: nim-memory.html
	scp nim-memory.html style.css ico@pruts.nl:/home/ico/websites/www.zevv.nl/nim-memory
