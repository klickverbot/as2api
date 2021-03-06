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


require 'parse/doccomment_parser'

class CommentData
  def initialize
    @blocks = []
  end

  def add_block(block)
    @blocks << block
  end

  def each_block
    @blocks.each do |block|
      yield block
    end
  end

  def [](i)
    @blocks[i]
  end

  def description
    @blocks[0]
  end

  def each_block_of_type(type)
    each_block do |block|
      yield block if block.is_a?(type)
    end
  end

  def has_blocktype?(type)
    each_block_of_type(type) do |block|
      return true
    end
    return false
  end

  def has_params?
    has_blocktype?(ParamBlockTag)
  end

  def has_exceptions?
    has_blocktype?(ThrowsBlockTag)
  end

  def has_seealso?
    has_blocktype?(SeeBlockTag)
  end

  def has_return?
    has_blocktype?(ReturnBlockTag)
  end

  def has_overload?
    has_blocktype?(OverloadBlockTag)
  end

  # Does the method comment include any info in addition to any basic
  # description block?
  def has_method_additional_info?
    has_params? || has_return? || has_exceptions? || has_seealso? || has_overload?
  end

  # Does the field comment include any info in addition to any basic description
  # block?
  def has_field_additional_info?
    has_seealso?
  end

  def each_exception
    each_block_of_type(ThrowsBlockTag) {|block| yield block }
  end

  def each_seealso
    each_block_of_type(SeeBlockTag) {|block| yield block }
  end

  def each_overload
    each_block_of_type(OverloadBlockTag) {|block| yield block }
  end

  def find_param(param_match)
    each_block_of_type(ParamBlockTag) do |block|
      return block if param_match === block.param_name
    end
    return nil
  end

  def find_return
    each_block_of_type(ReturnBlockTag) do |block|
      return block
    end
    return nil
  end

  def find_throws(exception_name)
    each_exception do |block|
      return block if block.exception_type.name == exception_name
    end
    nil
  end
end

class OurDocCommentHandler < ActionScript::ParseDoc::DocCommentHandler
  def initialize(comment_data, handler_config, type_namespace)
    @comment_data = comment_data
    @handler_config = handler_config
    @type_namespace = type_namespace
  end

  def comment_start(lineno)
    @block_handler = @handler_config.initial_block_handler
    @inline_handler = nil
    beginning_of_block(lineno)
  end

  def comment_end
    end_of_block
  end

  def text(text)
    if @inline_handler
      @inline_handler.text(text)
    else
      @block_handler.text(text)
    end
  end

  def start_paragraph_tag(tag)
    end_of_block
    @block_handler = @handler_config.handler_for(tag)
    beginning_of_block(tag.lineno)
  end

  def start_inline_tag(tag)
    @inline_handler = @block_handler.handler_for(tag)
    @inline_handler.start(@type_namespace, tag.lineno)
  end

  def end_inline_tag
    tag = @inline_handler.end
    @block_handler.add_inline(tag) if tag
    @inline_handler = nil
  end

  private

  def beginning_of_block(lineno)
    @block_handler.begin_block(@type_namespace, lineno)
  end

  def end_of_block
    block = @block_handler.end_block
    @comment_data.add_block(block) unless block.nil?
  end
end

class DocCommentParserConfig
  def initialize
    @initial_block_handler = nil
    @block_handlers = {}
  end

  attr_accessor :initial_block_handler

  def add_block_parser(name, handler)
    @block_handlers[name] = handler
    handler.handler = self
  end

  def handler_for(kind)
    handler = @block_handlers[kind.body]
    if handler.nil?
      parse_error("#{kind.source}:#{kind.lineno}: Unknown block tag @#{kind.body}")
      handler = NIL_HANDLER
    end
    handler
  end

  private

  def parse_error(msg)
    $stderr.puts(msg)
  end

end


class Tag
  def initialize(lineno)
    @lineno = lineno
  end

  attr_accessor :lineno

  def ==(o)
    o.respond_to?(:lineno) && lineno == o.lineno
  end
end

class LinkTag < Tag
  def initialize(lineno, target_ref, text)
    super(lineno)
    @target_ref = target_ref
    @text = text
  end

  attr_accessor :target_ref, :text

  def ==(o)
    super(o) && text==o.text && target_ref==o.target_ref
  end
end

class CodeTag < Tag
  def initialize(lineno, text)
    super(lineno)
    @text = text
  end

  attr_accessor :text
end


class BlockTag
  def initialize
    @inlines = []
  end

  def add_inline(inline)
    # coalesce multiple consecutive strings,
    last_inline = @inlines.last
    if inline.is_a?(String) && last_inline.is_a?(String)
      last_inline << inline
    else
      @inlines << inline
    end
  end

  def each_inline
    @inlines.each do |inline|
      yield inline
    end
  end

  def inlines
    @inlines
  end

  def clear
    @inlines.clear
  end

  def ==(o)
    o.respond_to?(:inlines) && inlines==o.inlines
  end
end


class ParamBlockTag < BlockTag
  attr_accessor :param_name

  def ==(o)
    super(o) && param_name==o.param_name
  end
end


class ThrowsBlockTag < BlockTag
  attr_accessor :exception_type
end


class SeeBlockTag < BlockTag
end


class ReturnBlockTag < BlockTag
end

class OverloadBlockTag < BlockTag
end


class InlineParser
  def start(type_namespace, lineno)
    @type_namespace = type_namespace
    @lineno = lineno
    @text = ""
  end

  def text(text)
    @text << text.to_s
  end
end


# creates a LinkTag inline
def create_link(type_namespace, text, lineno)
  if text =~ /^\s*([^()\s]+(?:\([^\)]*\))?)\s*(.+)?/m
    target = $1
    text = $2
    if target =~ /([^#]*)#(.*)/
      type_name = $1
      member_name = $2
    else
      type_name = target
      member_name = nil
    end
    if type_name == ""
      type_ref = type_namespace.ref_to_self
    else
      type_ref = type_namespace.ref_to(type_name, lineno)
    end
    if member_name
      if member_name =~ /\(/
	target_ref = type_ref.ref_method($`, lineno)
      else
	target_ref = type_ref.ref_member(member_name, lineno)
      end
    else
      target_ref = type_ref
    end
    return LinkTag.new(lineno, target_ref, text)
  end
  return nil
end


# handle {@link ...} in comments
class LinkInlineParser < InlineParser
  def end
    link = create_link(@type_namespace, @text, @lineno)
    if link.nil?
      "{@link #{@text}}"
    else
      link
    end
  end
end

# handle {@code ...} in comments
class CodeInlineParser < InlineParser
  def end; CodeTag.new(@lineno, @text); end
end


class BlockParser
  def initialize
    @inline_parsers = {}
    @data = nil
  end

  attr_accessor :handler

  def begin_block(type_namespace, lineno)
    @type_namespace = type_namespace
    @lineno = lineno
  end

  def end_block
    @data
  end

  def add_inline_parser(tag_name, parser)
    @inline_parsers[tag_name] = parser
  end

  def handler_for(tag)
    inline_parser = @inline_parsers[tag.body]
    if inline_parser.nil?
      $stderr.puts("#{tag.lineno}: Unknown inline tag #{tag.body.inspect} for #{self.class.name}")
      NIL_INLINE_PARSER
    else
      inline_parser
    end
  end

  def text(text)
    add_text(text.to_s)
  end

  def add_inline(tag)
    @data.add_inline(tag)
  end

  def add_text(text)
    raise "#{self.class.name} has no @data" unless @data
    @data.add_inline(text)
  end
end

class NilBlockParser < BlockParser
  def add_text(text); end
  def handler_for(tag); NIL_INLINE_PARSER; end
end

NIL_HANDLER = NilBlockParser.new


class NilInlineParser < InlineParser
  def end; nil; end
end

NIL_INLINE_PARSER = NilInlineParser.new

class ParamParser < BlockParser
  def begin_block(type_namespace, lineno)
    super(type_namespace, lineno)
    @data = ParamBlockTag.new
  end

  def end_block
    first_inline = @data.inlines[0]
    if first_inline =~ /\s*([^\s]+)\s+/
      @data.inlines[0] = $'
      @data.param_name = $1
    end
    @data
  end
end


class ThrowsParser < BlockParser
  def begin_block(type_namespace, lineno)
    super(type_namespace, lineno)
    @data = ThrowsBlockTag.new
  end

  def end_block
    first_inline = @data.inlines[0]
    if first_inline =~ /\A\s*([^\s]+)\s+/
      @data.inlines[0] = $'
      @data.exception_type = @type_namespace.ref_to($1)
      @data
    else
      nil
    end
  end
end


class ReturnParser < BlockParser
  def begin_block(type_namespace, lineno)
    super(type_namespace, lineno)
    @data = ReturnBlockTag.new
  end
end


class DescriptionParser < BlockParser
  def begin_block(type_namespace, lineno)
    super(type_namespace, lineno)
    @data = BlockTag.new
  end
end


class SeeParser < BlockParser
  def begin_block(type_namespace, lineno)
    super(type_namespace, lineno)
    @data = SeeBlockTag.new
  end

  def end_block
    @data.inlines.first =~ /\A\s*/
    case $'
      when /^['"]/
	# plain, 'string'-like see entry
      when /^</
	# HTML entry
      else
	# 'link' entry
	link = create_link(@type_namespace, @data.inlines.first, @lineno)
	unless link.nil?
	  @data.inlines[0] = link
	end
    end
    @data
  end
end


class OverloadParser < BlockParser
  def begin_block(type_namespace, lineno)
    super(type_namespace, lineno)
    @data = OverloadBlockTag.new
  end

  def end_block
    if @data.inlines.first =~ /\A\s*(#.*)/
      link = create_link(@type_namespace, $1, @lineno)
      unless link.nil?
	@data.inlines[0] = link
      end
    end
    @data
  end
end


#############################################################################


class ConfigBuilder
  def build_method_config
    config = build_config
    add_standard_block_parsers(config)
    config.add_block_parser("param", build_param_block_parser)
    config.add_block_parser("return", build_return_block_parser)
    config.add_block_parser("throws", build_throws_block_parser)
    config.add_block_parser("exception", build_throws_block_parser)
    config.add_block_parser("overload", build_overload_block_parser)
    return config
  end

  def build_field_config
    config = build_config
    add_standard_block_parsers(config)
    return config
  end

  def build_type_config
    config = build_config
    add_standard_block_parsers(config)
    config.add_block_parser("author", build_author_block_parser)
    return config
  end

  protected

  def build_config
    DocCommentParserConfig.new
  end

  def add_standard_block_parsers(config)
    config.initial_block_handler = build_description_block_parser
    config.add_block_parser("see", build_see_block_parser)
  end

  def add_common_inlines(block_parser)
    block_parser.add_inline_parser("link", LinkInlineParser.new)
    block_parser.add_inline_parser("code", CodeInlineParser.new)
  end

  def build_description_block_parser
    parser = DescriptionParser.new
    add_common_inlines(parser)
    parser
  end

  def build_param_block_parser
    parser = ParamParser.new
    add_common_inlines(parser)
    parser
  end

  def build_return_block_parser
    parser = ReturnParser.new
    add_common_inlines(parser)
    parser
  end

  def build_throws_block_parser
    parser = ThrowsParser.new
    add_common_inlines(parser)
    parser
  end

  def build_see_block_parser
    parser = SeeParser.new
    add_common_inlines(parser)
    parser
  end

  def build_author_block_parser
    NilBlockParser.new  # ignore @author tags
  end

  def build_overload_block_parser
    OverloadParser.new
  end
end

# vim:softtabstop=2:shiftwidth=2
