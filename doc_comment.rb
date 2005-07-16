
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
end

class OurDocCommentHandler < ActionScript::Parse::DocCommentHandler
  def initialize(comment_data, handler_config, type_resolver)
    @comment_data = comment_data
    @handler_config = handler_config
    @type_resolver = type_resolver
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
    @inline_handler.start(@type_resolver, tag.lineno)
  end

  def end_inline_tag
    @block_handler.add_inline(@inline_handler.end)
    @inline_handler = nil
  end

  private

  def beginning_of_block(lineno)
    @block_handler.begin_block(@type_resolver, lineno)
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
      parse_error("#{kind.lineno}: Unknown block tag @#{kind.body}")
      handler = NIL_HANDLER
    end
    handler
  end

  private

  def parse_error(msg)
    $stderr.puts(msg)
  end

end


class LinkTag
  def initialize(target, member, text)
    @target = target
    @member = member
    @text = text
  end

  attr_accessor :target, :member, :text
end

class CodeTag
  def initialize(text)
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
end


class ParamBlockTag < BlockTag
  attr_accessor :param_name
end


class ThrowsBlockTag < BlockTag
  attr_accessor :exception_type
end


class SeeBlockTag < BlockTag
end


class ReturnBlockTag < BlockTag
end


class InlineParser
  def start(type_resolver, lineno)
    @type_resolver = type_resolver
    @lineno = lineno
    @text = ""
  end

  def text(text)
    @text << text.to_s
  end
end


# creates a LinkTag inline
def create_link(type_resolver, text, lineno)
  if text =~ /^\s*([^\s]+(?:\([^\)]*\))?)\s*/
    target = $1
    text = $'
    # TODO: need a MemberProxy (and maybe Method+Field subclasses) with similar
    #       role to TypeProxy, to simplify this, and output_doccomment_inlinetag
    if target =~ /([^#]*)#(.*)/
      type_name = $1
      member_name = $2
    else
      type_name = target
      member_name = nil
    end
    if type_name == ""
      type_proxy = nil
    else
      type_proxy = type_resolver.resolve(type_name, lineno)
    end
    return LinkTag.new(type_proxy, member_name, text)
  end
  return nil
end


# handle {@link ...} in comments
class LinkInlineParser < InlineParser
  def end
    link = create_link(@type_resolver, @text, @lineno)
    if link.nil?
      "{@link #{@text}}"
    else
      link
    end
  end
end

# handle {@code ...} in comments
class CodeInlineParser < InlineParser
  def end; CodeTag.new(@text); end
end


class BlockParser
  def initialize
    @inline_parsers = {}
    @data = nil
  end

  attr_accessor :handler

  def begin_block(type_resolver, lineno)
    @type_resolver = type_resolver
    @lineno = lineno
  end

  def parse_line(text)
  end

  def end_block
    @data
  end

  def add_inline_parser(tag_name, parser)
    @inline_parsers[tag_name] = parser
  end

  def handler_for(tag)
    inline_parser = @inline_parsers[tag.body]
  end

  def text(text)
    add_text(text.to_s)
  end

  def add_inline(tag)
    @data.add_inline(tag)
  end

  def parse_inlines(input)
    text = input.text
    while text.length > 0
      if text =~ /\A\{@([^}\s]+)\s*([^}]*)\}/
	tag_name = $1
	tag_data = $2
	inline_parser = @inline_parsers[tag_name]
	if inline_parser.nil?
	  add_text($&)
	else
	  inline_parser.parse(@data, input.derive(tag_data))
	end
	text = $'
      elsif text =~ /\A.[^{]*/m
	add_text($&)
	text = $'
      else
	raise "#{input.lineno}: no match for #{text.inspect}"
      end
    end
  end

  def add_text(text)
    raise "#{self.class.name} has no @data" unless @data
    @data.add_inline(text)
  end
end

class NilBlockParser < BlockParser
  def add_text(text); end
end

NIL_HANDLER = NilBlockParser.new


class ParamParser < BlockParser
  def begin_block(type_resolver, lineno)
    super(type_resolver, lineno)
    @data = ParamBlockTag.new
  end

  def parse_line(input)
    if @data.param_name.nil?
      input.text =~ /\s*([^\s]+)\s+/
      @data.param_name = $1
      input = input.derive($')
    end
    parse_inlines(input)
  end
end


class ThrowsParser < BlockParser
  def begin_block(type_resolver, lineno)
    super(type_resolver, lineno)
    @data = ThrowsBlockTag.new
  end

  def end_block
      first_inline = @data.inlines[0]
      if first_inline =~ /\A\s*([^\s]+)\s+/
	@data.inlines[0] = $'
        @data.exception_type = @type_resolver.resolve($1)
	@data
      else
	nil
      end
  end
end


class ReturnParser < BlockParser
  def begin_block(type_resolver, lineno)
    super(type_resolver, lineno)
    @data = ReturnBlockTag.new
  end
  def parse_line(input)
    parse_inlines(input)
  end
end


class DescriptionParser < BlockParser
  def begin_block(type_resolver, lineno)
    super(type_resolver, lineno)
    @data = BlockTag.new
  end
end


class SeeParser < BlockParser
  def begin_block(type_resolver, lineno)
    super(type_resolver, lineno)
    @data = SeeBlockTag.new
  end

  def end_block
      @data.inlines.first =~ /\A\s*/
      case $'
	when /['"]/
	  # plain, 'string'-like see entry
	when /</
	  # HTML entry
	else
	  # 'link' entry
	  link = create_link(@type_resolver, @data.inlines.first, @lineno)
	  unless link.nil?
	    @data.inlines[0] = link
	  end
      end
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
end

# vim:softtabstop=2:shiftwidth=2
