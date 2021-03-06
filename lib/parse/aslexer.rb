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


require 'parse/lexer'

module ActionScript
module Parse

class CommentToken < ASToken
end

class NumberToken < ASToken
end

class HexNumberToken < ASToken
end

class SingleLineCommentToken < CommentToken
  def to_s
    "//#{@body}"
  end
end

class MultiLineCommentToken < CommentToken
  def to_s
    "/*#{@body}*/"
  end
end

class IncludeToken < ASToken
end

class WhitespaceToken < ASToken
end

class IdentifierToken < ASToken
end

class StringToken < ASToken
  def initialize(body, lineno)
    @body = unescape(body)
    @lineno = lineno
  end

  def to_s
    "\"#{escape(@body)}\""
  end

  def escape(text)
    text.gsub(/./m) do
      case $&
        when "\\" then "\\\\"
        when "\"" then "\\\""
	when "\n" then "\\n"
	when "\t" then "\\t"
        else $&
      end
    end
  end

  def unescape(text)
    escape = false
    text.gsub(/./) do
      if escape
        escape = false
        case $&
          when "\\" then "\\"
          when "n" then "\n"
          when "t" then "\t"
          else $&
        end
      else
        case $&
	  when "\\" then escape=true; ""
	  else $&
	end
      end
    end
  end
end

# "get" and "set" where initially included in this list, since they are used
# as modifiers to function declarations.  The are also allowed to appear as
# identifiers, unfortunately, so we treat them as such, and have the parser
# make special checks on the identifier body.
Keywords = [
  "as",
  "break",
  "case",
  "catch",
  "class",
  "const",
  "continue",
  "default",
  "dynamic",     # non-ECMA
  "delete",
  "do",
  "else",
  "extends",
  "false",
  "finally",
  "for",
  "function",
  "if",
  "implements",  # reserved, but unused in ECMA
  "import",
  "in",
  "instanceof",
  "interface",   # reserved, but unused in ECMA
  "intrinsic",   # non-ECMA
#  "is",         # not a keyword in AS
#  "namespace",  # not a keyword in AS
  "new",
  "null",
#  "package",    # can be an identifier is AS
  "private",
  "public",
  "return",
  "static",      # non-ECMA
  "super",
  "switch",
  "this",
  "throw",
  "true",
  "try",
  "typeof",
  "use",
  "var",
  "void",
  "while",
  "with"
]

Reserved = [
  "abstract",
  "debugger",
  "enum",
  "export",
  "goto",
  "native",
  "protected",
  "synchronized",
  "throws",
  "transient",
  "volatile"
]

Punctuation = [
  [:DivideAssign,         "/="],
  [:Divide,               "/"],
  [:BitNot,               "~"],
  [:RBrace,               "}"],
  [:OrAssign,             "||="],
  [:Or,                   "||"],
  [:BitOrAssign,          "|="],
  [:BitOr,                "|"],
  [:LBrace,               "{"],
  [:XOrAssign,            "^^="],
  [:XOr,                  "^^"],
  [:BitXOrAssign,         "^="],
  [:BitXOr,               "^"],
  [:RBracket,             "]"],
  [:LBracket,             "["],
  [:Hook,                 "?"],
  [:RShiftUnsignedAssign, ">>>="],
  [:RShiftUnsigned,       ">>>"],
  [:RShiftAssign,         ">>="],
  [:RShift,               ">>"],
  [:GreaterEquals,        ">="],
  [:Greater,              ">"],
  [:Same,                 "==="],
  [:Equals,               "=="],
  [:Assign,               "="],
  [:LessEquals,           "<="],
  [:LShiftAssign,         "<<="],
  [:LShift,               "<<"],
  [:Less,                 "<"],
  [:Semicolon,            ";"],
  [:Member,               "::"],
  [:Colon,                ":"],
  [:Ellipsis,             "..."],
  [:Dot,                  "."],
  [:MinusAssign,          "-="],
  [:Decrement,            "--"],
  [:Minus,                "-"],
  [:Comma,                ","],
  [:PlusAssign,           "+="],
  [:Increment,            "++"],
  [:Plus,                 "+"],
  [:StarAssign,           "*="],
  [:Star,                 "*"],
  [:RParen,               ")"],
  [:LParen,               "("],
  [:BitAndAssign,         "&="],
  [:AndAssign,            "&&="],
  [:And,                  "&&"],
  [:BitAnd,               "&"],
  [:ModuloAssign,         "%="],
  [:Modulo,               "%"],
  [:BangSame,             "!=="],
  [:BangEquals,           "!="],
  [:Bang,                 "!"]
]

  h =		"[0-9a-fA-F]"
  nl =		"\\n|\\r\\n|\\r|\\f"
  nonascii =	"[\\200-\\377]"
  unicode =	"\\\\#{h}{1,6}[ \\t\\r\\n\\f]?"
  escape =	"(?:#{unicode}|\\\\[ -~\\200-\\377])"
  nmstart =	"(?:[a-zA-Z_$]|#{nonascii}|#{escape})"
  nmchar =	"(?:[a-zA-Z0-9_$]|#{nonascii}|#{escape})"
  SINGLE_LINE_COMMENT = "//([^\n\r]*)"
  OMULTI_LINE_COMMENT = "/\\*"
  CMULTI_LINE_COMMENT = "\\*/"
  STRING_START1 = "'"
  STRING_END1 = "((?:(?:\\\\')|[\\t !\#$%&(-~]|#{nl}|\"|#{nonascii}|#{escape})*)\'"
  STRING_START2 = '"'
  STRING_END2 = "((?:(?:\\\\\")|[\\t !\#$%&(-~]|#{nl}|'|#{nonascii}|#{escape})*)\""
  WHITESPACE = "[ \t\r\n\f]+"


  IDENT =	"#{nmstart}#{nmchar}*"
#  name =	"#{nmchar}+"
  NUM	 =	"[0-9]+|[0-9]*\\.[0-9]+"
  HEX_NUM =	"0x#{h}+"
#  string =	"#{string1}|#{string2}"
  w =		"[ \t\r\n\f]*"

class ASLexer < AbstractLexer

  def lex_simple_token(class_sym, match)
    ActionScript::Parse.const_get(class_sym).new(@lineno)
  end

  def lex_key_or_ident_token(match)
    body = match[0]
    class_sym = @@keyword_tokens[body]
    if class_sym
      lex_simple_token(class_sym, match)
    else
      lex_simplebody_token(:IdentifierToken, match)
    end
  end

  def self.keyword_tokens=(toks)
    @@keyword_tokens = toks
  end

  def lex_simplebody_token(class_sym, match)
    ActionScript::Parse.const_get(class_sym).new(match[0], @lineno)
  end

  def lex_singlelinecoomment_token(class_sym, match)
    SingleLineCommentToken.new(match[1], @lineno)
  end

  def lex_multilinecomment_token(class_sym, match)
    lineno = @lineno
    comment = match.scan_until(/\*\//o)
    raise "#{@lineno}:unexpected EOF in comment" if comment.nil?
    MultiLineCommentToken.new(comment[0, comment.length-2], lineno)
  end

  def lex_string1_token(class_sym, match)
    str = match.scan_until(/#{STRING_END1}/o)
    raise "#{@lineno}:unexpected EOF in string" if str.nil?
    StringToken.new(str[0, str.length-1], @lineno)
  end

  def lex_string2_token(class_sym, match)
    str = match.scan_until(/#{STRING_END2}/o)
    raise "#{@lineno}:unexpected EOF in string" if str.nil?
    StringToken.new(str[0, str.length-1], @lineno)
  end


end

def self.build_lexer
  builder = LexerBuilder.new(ActionScript::Parse)

  # TODO: whitespace tokens don't span lines, which might not be the expected
  #       behaviour
  builder.add_match(WHITESPACE, :lex_simplebody_token, :WhitespaceToken)

  builder.add_match("^#include [^\r\n]*", :lex_simplebody_token, :IncludeToken)

  builder.add_match(SINGLE_LINE_COMMENT, :lex_singlelinecoomment_token, :SingleLineCommentToken)

  builder.add_match(OMULTI_LINE_COMMENT, :lex_multilinecomment_token, :MultiLineCommentToken)

  keyword_tokens = {}
  Keywords.each do |keyword|
    builder.create_keytoken_class(keyword)
    keyword_tokens[keyword] = "#{keyword.capitalize}Token".to_sym
  end

  ASLexer.keyword_tokens = keyword_tokens

  Punctuation.each do |punct|
    builder.make_punctuation_token(*punct)
  end

  builder.add_match(IDENT, :lex_key_or_ident_token, nil)

  builder.add_match(STRING_START1, :lex_string1_token, :StringToken)

  builder.add_match(STRING_START2, :lex_string2_token, :StringToken)

  builder.add_match(HEX_NUM, :lex_simplebody_token, :HexNumberToken)
  builder.add_match(NUM, :lex_simplebody_token, :NumberToken)

  builder.build_lexer(ASLexer)
end

build_lexer

class SkipASLexer
  def initialize(lexer)
    @lex = lexer
    @handler = nil
  end

  def handler=(handler)
    @handler = handler
  end

  def get_next
    while skip?(tok=@lex.get_next)
      notify(tok)
    end
    tok
  end

  def peek_next
    while skip?(tok=@lex.peek_next)
      notify(tok)
      @lex.get_next
    end
    tok
  end

  protected

  def skip?(tok)
    tok.is_a?(CommentToken) || tok.is_a?(WhitespaceToken) || tok.is_a?(IncludeToken)
  end

  def notify(tok)
    unless @handler.nil?
      @handler.comment(tok.body)
    end
  end
end


end  # module Parse
end  # module ActionScript


# vim:shiftwidth=2:softtabstop=2
