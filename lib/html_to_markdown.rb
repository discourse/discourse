# frozen_string_literal: true

require "nokogiri"

class HtmlToMarkdown

  class Block < Struct.new(:name, :head, :body, :opened, :markdown)
    def initialize(name, head = "", body = "", opened = false, markdown = +"")
      super
    end
  end

  def initialize(html, opts = {})
    @opts = opts || {}
    @doc = fix_span_elements(Nokogiri::HTML(html))

    remove_whitespaces!
  end

  # If a `<div>` is within a `<span>` that's invalid, so let's hoist the `<div>` up
  INLINE_ELEMENTS ||= %w{span font}
  BLOCK_ELEMENTS ||= %w{div p}
  def fix_span_elements(node)
    if (INLINE_ELEMENTS.include?(node.name) && BLOCK_ELEMENTS.any? { |e| node.at(e) })
      node.swap(node.children)
    end

    node.children.each { |c| fix_span_elements(c) }
    node
  end

  def remove_whitespaces!
    @doc.traverse do |node|
      if node.is_a? Nokogiri::XML::Text
        node.content = node.content.gsub(/\A[[:space:]]+/, "") if node.previous_element&.description&.block?
        node.content = node.content.gsub(/\A[[:space:]]+/, "") if node.previous_element.nil? && node.parent.description&.block?
        node.content = node.content.gsub(/[[:space:]]+\z/, "") if node.next_element&.description&.block?
        node.content = node.content.gsub(/[[:space:]]+\z/, "") if node.next_element.nil? && node.parent.description&.block?
        node.content = node.content.gsub(/\r\n?/, "\n")
        node.remove if node.content.empty?
      end
    end
  end

  def to_markdown
    @stack = [Block.new("root")]
    @markdown = +""
    traverse(@doc)
    @markdown << format_block
    @markdown.gsub!(/\n{3,}/, "\n\n")
    @markdown.strip!
    @markdown
  end

  def traverse(node)
    node.children.each { |n| visit(n) }
  end

  def visit(node)
    return if node["style"] && node["style"][/display\s*:\s*none/]

    if node.description&.block? && node.parent&.description&.block? && @stack[-1].markdown.size > 0
      block = @stack[-1].dup
      @markdown << format_block
      block.markdown = +""
      block.opened = true
      @stack << block
    end

    visitor = "visit_#{node.name}"
    respond_to?(visitor) ? send(visitor, node) : traverse(node)
  end

  BLACKLISTED ||= %w{button datalist fieldset form input label legend meter optgroup option output progress select textarea style script}
  BLACKLISTED.each do |tag|
    class_eval <<-RUBY
      def visit_#{tag}(node)
        ""
      end
    RUBY
  end

  def visit_pre(node)
    code = node.children.find { |c| c.name == "code" }
    code_class = code ? code["class"] : ""
    lang = code_class ? code_class[/lang-(\w+)/, 1] : ""
    pre = Block.new("pre")
    pre.markdown = +"```#{lang}\n"
    @stack << pre
    traverse(node)
    pre.markdown << "\n```\n"
    @markdown << format_block
  end

  def visit_blockquote(node)
    @stack << Block.new("blockquote", "> ", "> ")
    traverse(node)
    @markdown << format_block
  end

  BLOCK_WITH_NEWLINE ||= %w{div p}
  BLOCK_WITH_NEWLINE.each do |tag|
    class_eval <<-RUBY
      def visit_#{tag}(node)
        @stack << Block.new("#{tag}")
        traverse(node)
        @markdown << format_block
        @markdown << "\n"
      end
    RUBY
  end

  BLOCK_LIST ||= %w{menu ol ul}
  BLOCK_LIST.each do |tag|
    class_eval <<-RUBY
      def visit_#{tag}(node)
        @stack << Block.new("#{tag}")
        traverse(node)
        @markdown << format_block
      end
    RUBY
  end

  def visit_li(node)
    parent = @stack.reverse.find { |n| n.name[/ul|ol|menu/] }
    prefix = parent&.name == "ol" ? "1. " : "- "
    @stack << Block.new("li", prefix, "  ")
    traverse(node)
    @markdown << format_block
  end

  (1..6).each do |n|
    class_eval <<-RUBY
      def visit_h#{n}(node)
        @stack << Block.new("h#{n}", "#" * #{n} + " ")
        traverse(node)
        @markdown << format_block
      end
    RUBY
  end

  WHITELISTED ||= %w{del ins kbd s small strike sub sup}
  WHITELISTED.each do |tag|
    class_eval <<-RUBY
      def visit_#{tag}(node)
        @stack[-1].markdown << "<#{tag}>"
        traverse(node)
        @stack[-1].markdown << "</#{tag}>"
      end
    RUBY
  end

  def visit_abbr(node)
    @stack[-1].markdown << (node["title"].present? ? %Q[<abbr title="#{node["title"]}">] : "<abbr>")
    traverse(node)
    @stack[-1].markdown << "</abbr>"
  end

  def visit_img(node)
    if is_valid_src?(node["src"]) && is_visible_img?(node)
      if @opts[:keep_img_tags]
        @stack[-1].markdown << node.to_html
      else
        title = node["alt"].presence || node["title"].presence
        @stack[-1].markdown << "![#{title}](#{node["src"]})"
      end
    end
  end

  def visit_a(node)
    if is_valid_href?(node["href"])
      @stack[-1].markdown << "["
      traverse(node)
      @stack[-1].markdown << "](#{node["href"]})"
    else
      traverse(node)
    end
  end

  def visit_tt(node)
    @stack[-1].markdown << "`"
    traverse(node)
    @stack[-1].markdown << "`"
  end

  def visit_code(node)
    @stack.reverse.find { |n| n.name["pre"] } ? traverse(node) : visit_tt(node)
  end

  def visit_br(node)
    return if node.previous_sibling.nil? && EMPHASIS.include?(node.parent.name)
    return if node.parent.name == "p" && (node.next_sibling&.text || "").start_with?("\n")
    @stack[-1].markdown << "\n"
  end

  def visit_hr(node)
    @stack[-1].markdown << "\n\n---\n\n"
  end

  EMPHASIS ||= %w{b strong i em}
  EMPHASIS.each do |tag|
    class_eval <<-RUBY
      def visit_#{tag}(node)
        return if node.text.empty?
        return @stack[-1].markdown << " " if node.text.blank?
        times = "#{tag}" == "i" || "#{tag}" == "em" ? 1 : 2
        delimiter = (node.text["*"] ? "_" : "*") * times
        @stack[-1].markdown << " " if node.text[0] == " "
        @stack[-1].markdown << delimiter
        traverse(node)
        @stack[-1].markdown.gsub!(/\n+$/, "")
        if @stack[-1].markdown[-1] == " "
          @stack[-1].markdown.chomp!(" ")
          append_space = true
        end
        @stack[-1].markdown << delimiter
        @stack[-1].markdown << " " if append_space
      end
    RUBY
  end

  def visit_text(node)
    node.content = node.content.gsub(/\A[[:space:]]+/, "") if node.previous_element.nil? && EMPHASIS.include?(node.parent.name)
    indent = node.text[/^\s+/] || ""
    text = node.text.gsub(/^\s+/, "").gsub(/\s{2,}/, " ")
    @stack[-1].markdown << [indent, text].join("")
  end

  def format_block
    lines = @stack[-1].markdown.each_line.map do |line|
      prefix = @stack.map { |b| b.opened ? b.body : b.head }.join
      @stack.each { |b| b.opened = true }
      prefix + line.rstrip
    end
    @stack.pop
    (lines + [""]).join("\n")
  end

  def is_valid_href?(href)
    href.present? && (href.start_with?("http") || href.start_with?("www."))
  end

  def is_valid_src?(src)
    return false if src.blank?
    return true  if @opts[:keep_cid_imgs] && src.start_with?("cid:")
    src.start_with?("http") || src.start_with?("www.")
  end

  def is_visible_img?(img)
    return false if img["width"].present?  && img["width"].to_i == 0
    return false if img["height"].present? && img["height"].to_i == 0
    return false if img["style"].present?  && img["style"][/(width|height)\s*:\s*0/]
    true
  end

end
