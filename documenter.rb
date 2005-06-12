
require 'parse/lexer'  # TODO: remove this requirement
require 'parse/as_io'
require 'api_loader'




def simple_parse(input)
  as_io = ASIO.new(input)
  lex = DocASLexer.new(ActionScript::Parse::ASLexer.new(as_io))
  parse = DocASParser.new(lex)
  handler = DocASHandler.new
  parse.handler = handler
  parse.parse_compilation_unit
  handler.defined_type
end


BOM = "\357\273\277"

# Look for a byte-order-marker in the first 3 bytes of io.
# Eats the BOM and returns true on finding one; rewinds the stream to its
# start and returns false if none is found.
def detect_bom?(io)
  return true if io.read(3) == BOM
  io.seek(0)
  false
end


# lists the .as files in 'path', and it's subdirectories
def each_source(path)
  require 'find'
  path = path.sub(/\/+$/, "")
  Find.find(path) do |f|
    base = File.basename(f)
    # Ignore anything named 'CVS', or starting with a dot
    Find.prune if base =~ /^\./ || base == "CVS"
    if base =~ /\.as$/
      yield f[path.length+1, f.length]
    end
  end
end

