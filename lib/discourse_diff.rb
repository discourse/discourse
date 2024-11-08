# frozen_string_literal: true

class DiscourseDiff
  MAX_DIFFERENCE = 200

  def initialize(before, after)
    @before = before
    @after = after
    before_html = tokenize_html_blocks(@before)
    after_html = tokenize_html_blocks(@after)
    before_markdown = tokenize_line(CGI.escapeHTML(@before))
    after_markdown = tokenize_line(CGI.escapeHTML(@after))

    @block_by_block_diff = ONPDiff.new(before_html, after_html).paragraph_diff
    @line_by_line_diff = ONPDiff.new(before_markdown, after_markdown).short_diff
  end

  def inline_html
    i = 0
    inline = []
    while i < @block_by_block_diff.size
      op_code = @block_by_block_diff[i][1]
      if op_code == :common
        inline << @block_by_block_diff[i][0]
      else
        if op_code == :delete
          opposite_op_code = :add
          klass = "del"
          first = i
          second = i + 1
        else
          opposite_op_code = :delete
          klass = "ins"
          first = i + 1
          second = i
        end

        if i + 1 < @block_by_block_diff.size && @block_by_block_diff[i + 1][1] == opposite_op_code
          diff =
            ONPDiff.new(
              tokenize_html(@block_by_block_diff[first][0]),
              tokenize_html(@block_by_block_diff[second][0]),
            ).diff
          inline << generate_inline_html(diff)
          i += 1
        else
          inline << add_class_or_wrap_in_tags(@block_by_block_diff[i][0], klass)
        end
      end
      i += 1
    end

    "<div class=\"inline-diff\">#{inline.join}</div>"
  end

  def side_by_side_html
    i = 0
    left, right = [], []
    while i < @block_by_block_diff.size
      op_code = @block_by_block_diff[i][1]
      if op_code == :common
        left << @block_by_block_diff[i][0]
        right << @block_by_block_diff[i][0]
      else
        if op_code == :delete
          opposite_op_code = :add
          side = left
          klass = "del"
          first = i
          second = i + 1
        else
          opposite_op_code = :delete
          side = right
          klass = "ins"
          first = i + 1
          second = i
        end

        if i + 1 < @block_by_block_diff.size && @block_by_block_diff[i + 1][1] == opposite_op_code
          diff =
            ONPDiff.new(
              tokenize_html(@block_by_block_diff[first][0]),
              tokenize_html(@block_by_block_diff[second][0]),
            ).diff
          deleted, inserted = generate_side_by_side_html(diff)
          left << deleted
          right << inserted
          i += 1
        else
          side << add_class_or_wrap_in_tags(@block_by_block_diff[i][0], klass)
        end
      end
      i += 1
    end

    "<div class=\"revision-content\">#{left.join}</div><div class=\"revision-content\">#{right.join}</div>"
  end

  def side_by_side_markdown
    i = 0
    table = ["<table class=\"markdown\">"]
    while i < @line_by_line_diff.size
      table << "<tr>"
      op_code = @line_by_line_diff[i][1]
      if op_code == :common
        table << "<td>#{@line_by_line_diff[i][0]}</td>"
        table << "<td>#{@line_by_line_diff[i][0]}</td>"
      else
        if op_code == :delete
          opposite_op_code = :add
          first = i
          second = i + 1
        else
          opposite_op_code = :delete
          first = i + 1
          second = i
        end

        if i + 1 < @line_by_line_diff.size && @line_by_line_diff[i + 1][1] == opposite_op_code
          before_tokens, after_tokens =
            tokenize_markdown(@line_by_line_diff[first][0]),
            tokenize_markdown(@line_by_line_diff[second][0])
          if (before_tokens.size - after_tokens.size).abs > MAX_DIFFERENCE
            before_tokens, after_tokens =
              tokenize_line(@line_by_line_diff[first][0]),
              tokenize_line(@line_by_line_diff[second][0])
          end
          diff = ONPDiff.new(before_tokens, after_tokens).short_diff
          deleted, inserted = generate_side_by_side_markdown(diff)
          table << "<td class=\"diff-del\">#{deleted.join}</td>"
          table << "<td class=\"diff-ins\">#{inserted.join}</td>"
          i += 1
        else
          if op_code == :delete
            table << "<td class=\"diff-del\">#{@line_by_line_diff[i][0]}</td>"
            table << "<td></td>"
          else
            table << "<td></td>"
            table << "<td class=\"diff-ins\">#{@line_by_line_diff[i][0]}</td>"
          end
        end
      end
      table << "</tr>"
      i += 1
    end
    table << "</table>"

    table.join
  end

  private

  def tokenize_line(text)
    text.scan(/[^\r\n]+[\r\n]*/)
  end

  def tokenize_markdown(text)
    t, tokens = [], []
    i = 0
    while i < text.size
      if text[i] =~ /\w/
        t << text[i]
      elsif text[i] =~ /[ \t]/ && t.join =~ /\A\w+\z/
        begin
          t << text[i]
          i += 1
        end while i < text.size && text[i] =~ /[ \t]/
        i -= 1
        tokens << t.join
        t = []
      else
        tokens << t.join if t.size > 0
        tokens << text[i]
        t = []
      end
      i += 1
    end
    tokens << t.join if t.size > 0
    tokens
  end

  def tokenize_html_blocks(html)
    Nokogiri::HTML5.fragment(html).search("./*").map(&:to_html)
  end

  def tokenize_html(html)
    HtmlTokenizer.tokenize(html)
  end

  def add_class_or_wrap_in_tags(html_or_text, klass)
    result = html_or_text.dup
    index_of_next_chevron = result.index(">")
    if result.size > 0 && result[0] == "<" && index_of_next_chevron
      index_of_class = result.index("class=")
      if index_of_class.nil? || index_of_class > index_of_next_chevron
        # we do not have a class for the current tag
        # add it right before the ">"
        result.insert(index_of_next_chevron, " class=\"diff-#{klass}\"")
      else
        # we have a class, insert it at the beginning if not already present
        classes = result[/class=(["'])([^\1]*)\1/, 2]
        if classes.include?("diff-#{klass}")
          result
        else
          result.insert(index_of_class + "class=".size + 1, "diff-#{klass} ")
        end
      end
    else
      "<#{klass}>#{result}</#{klass}>"
    end
  end

  def generate_inline_html(diff)
    inline = []
    diff.each do |d|
      case d[1]
      when :common
        inline << d[0]
      when :delete
        inline << add_class_or_wrap_in_tags(d[0], "del")
      when :add
        inline << add_class_or_wrap_in_tags(d[0], "ins")
      end
    end
    inline
  end

  def generate_side_by_side_html(diff)
    deleted, inserted = [], []
    diff.each do |d|
      case d[1]
      when :common
        deleted << d[0]
        inserted << d[0]
      when :delete
        deleted << add_class_or_wrap_in_tags(d[0], "del")
      when :add
        inserted << add_class_or_wrap_in_tags(d[0], "ins")
      end
    end
    [deleted, inserted]
  end

  def generate_side_by_side_markdown(diff)
    deleted, inserted = [], []
    diff.each do |d|
      case d[1]
      when :common
        deleted << d[0]
        inserted << d[0]
      when :delete
        deleted << "<del>#{d[0]}</del>"
      when :add
        inserted << "<ins>#{d[0]}</ins>"
      end
    end
    [deleted, inserted]
  end

  class HtmlTokenizer < Nokogiri::XML::SAX::Document
    attr_accessor :tokens

    def initialize
      @tokens = []
    end

    def self.tokenize(html)
      me = new
      parser = Nokogiri::HTML::SAX::Parser.new(me)
      parser.parse("<html><body>#{html}</body></html>")
      me.tokens
    end

    USELESS_TAGS = %w[html body].freeze
    def start_element(name, attributes = [])
      return if USELESS_TAGS.include?(name)
      attrs = attributes.map { |a| " #{a[0]}=\"#{CGI.escapeHTML(a[1])}\"" }.join
      @tokens << "<#{name}#{attrs}>"
    end

    AUTOCLOSING_TAGS = %w[area base br col embed hr img input meta].freeze
    def end_element(name)
      return if USELESS_TAGS.include?(name) || AUTOCLOSING_TAGS.include?(name)
      @tokens << "</#{name}>"
    end

    def characters(string)
      @tokens.concat string.scan(/\W|\w+[ \t]*/).map { |x| CGI.escapeHTML(x) }
    end
  end
end
