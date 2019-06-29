
nim-memory.html: nim-memory.md
	asciidoctor nim-memory.md

clean:
	rm -f nim-memory.html

div: nim-memory.html
	todiv nim-memory.html *jpg
