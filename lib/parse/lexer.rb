# 
# Part of as2api - http://www.badgers-in-foil.co.uk/projects/as2api/
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#


require 'strscan'

module ActionScript
module Parse

# TODO Create an EOFToken (so that we can report its line number)

class ASToken
  def initialize(body, lineno)
    @body = body
    @lineno = lineno
    @source = nil
  end
  def body
    @body
  end
  attr_accessor :lineno
  def to_s
    @body
  end
  attr_accessor :source
end


class AbstractLexer

  def initialize(io)
    @io = io
    @tokens = Array.new
    @eof = false
    @source = nil
    @lineno = io.lineno + 1
  end

  attr_accessor :source

  def get_next
    nextt
  end

  def peek_next
    check_fill()
    @tokens[0]
  end

  protected

  def nextt
    check_fill()
    @tokens.shift
  end

  def check_fill
    if @tokens.empty? && !@io.eof?
      fill()
    end
  end

  def emit(token)
    @lineno += token.body.scan(/\r\n|\r|\n/).length
    token.source = @source
    @tokens << token
  end

  def parse_error(text)
    raise "#{@io.lineno}:no lexigraphic match for text starting '#{text}'"
  end
  def warn(message)
    $stderr.puts(message)
  end
end


# This is a Lexer for the tokens of ActionScript 2.0.
class LexerBuilder
  # This is a naive lexer implementation that considers input line-by-line,
  # with special cases to handle multiline tokens (strings, comments).
  # spacial care must be taken to declaire tokens in the 'correct' order (as
  # the fist match wins), and to cope with keyword/identifier ambiguity
  # (keywords have '\b' regexp-lookahead appended)

  def initialize(token_module)
    @matches = []
    @token_module = token_module
  end

  def make_match(match)
    match.gsub("/", "\\/").gsub("\n", "\\n")
  end

  def add_match(match, lex_meth_sym, tok_class_sym)
    @matches << [make_match(match), lex_meth_sym, tok_class_sym]
  end

  def create_keytoken_class(name)
    the_class = Class.new(ASToken)
    the_class.class_eval <<-EOE
    def initialize(lineno)
      super("#{name}", lineno)
    end
    EOE
    @token_module.const_set("#{name.capitalize}Token".to_sym, the_class)
  end

  def make_simple_token(name, value, match)
    class_name = "#{name}Token"
    the_class = Class.new(ASToken)
    the_class.class_eval <<-EOE
    def initialize(lineno)
      super("#{value}", lineno)
    end
    EOE
    @token_module.const_set(class_name, the_class)

    add_match(match, :lex_simple_token, class_name.to_sym)
  end

  def make_keyword_token(name)
    make_simple_token(name.capitalize, name, "#{name}\\b")
  end

  def make_punctuation_token(name, value)
    make_simple_token(name, value, Regexp.escape(value))
  end

  def build_lexer(target_class)
    text = <<-EOS
      def fill
        input = StringScanner.new(@io.read)
        until input.eos?
    EOS
    @matches.each_with_index do |token_match, index|
      re, lex_method, tok_class = token_match
      text << "if input.scan(/#{re}/)\n"
      if tok_class
      	text << "  emit(#{lex_method.to_s}(:#{tok_class.to_s}, input))\n"
      else
      	text << "  emit(#{lex_method.to_s}(input))\n"
      end
      text << "  next\n"
      text << "end\n"
    end
    text << <<-EOS
          # no previous regexp matched,
          parse_error(input.rest)
        end
      end
    EOS
    target_class.class_eval(text)
  end

end

end # module Parse
end # module ActionScript
