# frozen_string_literal: true

require "securerandom"

class HtmlToMarkdown
  def initialize(html, opts = {})
    @opts = opts
    @within_html_block = false

    # we're only interested in <body>
    @doc = Nokogiri.HTML5(html).at("body")

    remove_not_allowed!(@doc)
    remove_hidden!(@doc)
    hoist_line_breaks!(@doc)
    remove_whitespaces!(@doc)
  end

  def to_markdown
    traverse(@doc).gsub(/\n{2,}/, "\n\n").strip
  end

  private

  def strip_newlines(string)
    string.gsub(/\n/, " ")&.squeeze(" ")
  end

  def remove_not_allowed!(doc)
    allowed = Set.new(@opts[:additional_allowed_tags] || [])

    HtmlToMarkdown.private_instance_methods.each do |m|
      if tag = m.to_s[/^visit_(.+)/, 1]
        allowed << tag
      end
    end

    @doc.traverse { |node| node.remove if !allowed.include?(node.name) }
  end

  def remove_hidden!(doc)
    @doc.css("[hidden]").remove
    @doc.css("img[width]").each { |n| n.remove if n["width"].to_i <= 0 }
    @doc.css("img[height]").each { |n| n.remove if n["height"].to_i <= 0 }
  end

  # When there's a <br> inside an inline element, split the inline element around the <br>
  def hoist_line_breaks!(doc)
    klass = "_" + SecureRandom.hex
    doc.css("br").each { |br| br.add_class(klass) }

    loop do
      changed = false

      doc
        .css("br.#{klass}")
        .each do |br|
          parent = br.parent

          if block?(parent)
            br.remove_class(klass)
          else
            before, after = parent.children.slice_when { |n| n == br }.to_a

            if before.size > 1
              b = doc.document.create_element(parent.name)
              before[0...-1].each { |c| b.add_child(c) }
              parent.previous = b if b.inner_html.present?
            end

            if after.present?
              a = doc.document.create_element(parent.name)
              after.each { |c| a.add_child(c) }
              parent.next = a if a.inner_html.present?
            end

            parent.replace(br)

            changed = true
          end
        end

      break if !changed
    end
  end

  # Removes most of the unnecessary white spaces for better markdown conversion
  # Loosely based on the CSS' White Space Processing Rules (https://www.w3.org/TR/css-text-3/#white-space-rules)
  def remove_whitespaces!(node)
    return true if "pre" == node.name

    node
      .children
      .chunk { |n| is_inline?(n) }
      .each do |inline, nodes|
        if inline
          collapse_spaces!(nodes) && remove_trailing_space!(nodes)
        else
          nodes.each { |n| remove_whitespaces!(n) }
        end
      end
  end

  def is_inline?(node)
    node.text? ||
      ("br" != node.name && node.description&.inline? && node.children.all? { |n| is_inline?(n) })
  end

  def collapse_spaces!(nodes, was_space = true)
    nodes.each do |node|
      if node.text?
        text = String.new

        node.text.chars.each do |c|
          if c[/[[:space:]]/]
            text << " " if !was_space
            was_space = true
          else
            text << c
            was_space = false
          end
        end

        node.content = text
      else
        node.children.each { |n| was_space = collapse_spaces!([n], was_space) }
      end
    end

    was_space
  end

  def remove_trailing_space!(nodes)
    last = nodes[-1]

    if last.text?
      last.content = last.content[0...-1] if last.content[-1] == " "
    elsif last.children.present?
      remove_trailing_space!(last.children)
    end
  end

  def traverse(node, within_html_block: false)
    within_html_block_changed = false
    if within_html_block
      within_html_block_changed = true
      @within_html_block = true
    end

    text = node.children.map { |n| visit(n) }.join
    @within_html_block = false if within_html_block_changed
    text
  end

  def visit(node)
    visitor = "visit_#{node.name}"
    send(visitor, node) if respond_to?(visitor, true)
  end

  ALLOWED_IMG_SRCS = %w[http:// https:// www.]

  def allowed_hrefs
    @allowed_hrefs ||=
      begin
        hrefs = SiteSetting.allowed_href_schemes.split("|").map { |scheme| "#{scheme}:" }.to_set
        ALLOWED_IMG_SRCS.each { |src| hrefs << src }
        hrefs << "mailto:"
        hrefs.to_a
      end
  end

  def visit_a(node)
    if node["href"].present? && node["href"].start_with?(*allowed_hrefs)
      "[#{traverse(node)}](#{node["href"]})"
    else
      traverse(node)
    end
  end

  def visit_img(node)
    return if node["src"].blank?

    node["alt"] = strip_newlines(node["alt"]) if node["alt"].present?
    node["title"] = strip_newlines(node["title"]) if node["title"].present?

    if @opts[:keep_img_tags]
      node.to_html
    elsif @opts[:keep_cid_imgs] && node["src"].start_with?("cid:")
      node.to_html
    elsif node["src"].start_with?(*ALLOWED_IMG_SRCS)
      width = node["width"].to_i
      height = node["height"].to_i
      dimensions = "|#{width}x#{height}" if width > 0 && height > 0
      "![#{node["alt"] || node["title"]}#{dimensions}](#{node["src"]})"
    end
  end

  ALLOWED = %w[kbd del ins small big sub sup dl dd dt mark]
  ALLOWED.each do |tag|
    define_method("visit_#{tag}") do |node|
      "<#{tag}>#{traverse(node, within_html_block: true)}</#{tag}>"
    end
  end

  def visit_blockquote(node)
    text = traverse(node)
    text.strip!
    text.gsub!(/\n{2,}/, "\n\n")
    text.gsub!(/^/, "> ")
    "\n\n#{text}\n\n"
  end

  BLOCKS = %w[div tr]
  BLOCKS.each do |tag|
    define_method("visit_#{tag}") do |node|
      prefix = block?(node.previous_element) ? "" : "\n"
      "#{prefix}#{traverse(node)}\n"
    end
  end

  def visit_p(node)
    "\n\n#{traverse(node)}\n\n"
  end

  TRAVERSABLES = %w[aside font span thead tbody tfoot u center]
  TRAVERSABLES.each { |tag| define_method("visit_#{tag}") { |node| traverse(node) } }

  def visit_tt(node)
    "`#{traverse(node)}`"
  end

  def visit_code(node)
    node.ancestors("pre").present? ? traverse(node) : visit_tt(node)
  end

  def visit_pre(node)
    text = traverse(node)
    fence = text["`"] ? "~~~" : "```"
    code = node.at("code")
    code_class = code ? code["class"] : ""
    lang = code_class ? code_class[/lang-(\w+)/, 1] : ""
    "\n\n#{fence}#{lang}\n#{traverse(node)}\n#{fence}\n\n"
  end

  def visit_br(node)
    "\n"
  end

  def visit_hr(node)
    "\n\n---\n\n"
  end

  def visit_abbr(node)
    title = node["title"].presence
    attributes = { title: } if title
    create_element("abbr", traverse(node, within_html_block: true), attributes).to_html
  end

  def visit_acronym(node)
    visit_abbr(node)
  end

  (1..6).each { |n| define_method("visit_h#{n}") { |node| "#{"#" * n} #{traverse(node)}" } }

  def visit_table(node)
    if (rows = extract_rows(node))
      headers = rows[0].css("td, th")
      text = "| " + headers.map { |td| traverse(td).gsub(/\n/, "<br>") }.join(" | ") + " |\n"
      text << "| " + (["-"] * headers.size).join(" | ") + " |\n"
      rows[1..-1].each do |row|
        text << "| " + row.css("td").map { |td| traverse(td).gsub(/\n/, "<br>") }.join(" | ") +
          " |\n"
      end
      "\n\n#{text}\n\n"
    else
      "<table>\n#{traverse(node, within_html_block: true)}</table>"
    end
  end

  def extract_rows(table)
    return if table.ancestors("table").present?
    return if (rows = table.css("tr")).empty?
    headers_count = rows[0].css("td, th").size
    return if rows[1..-1].any? { |row| row.css("td").size != headers_count }
    rows
  end

  def visit_tr(node)
    text = traverse(node)
    @within_html_block ? "<tr>\n#{text}</tr>\n" : text
  end

  TABLE_CELLS = %w[th td]
  TABLE_CELLS.each do |tag|
    define_method("visit_#{tag}") do |node|
      text = traverse(node)
      if @within_html_block
        element = create_element(tag, "\n\n#{text}\n\n")
        node.attribute_nodes.each do |a|
          element[a.name] = a.value if %w[rowspan colspan].include?(a.name)
        end
        "#{element.to_html}\n"
      else
        text
      end
    end
  end

  LISTS = %w[ul ol]
  LISTS.each do |tag|
    define_method("visit_#{tag}") do |node|
      prefix = block?(node.previous_element) ? "" : "\n"
      suffix = node.ancestors("ul, ol, li").size > 0 ? "" : "\n"
      "#{prefix}#{traverse(node)}#{suffix}"
    end
  end

  def visit_li(node)
    text = traverse(node)

    lists = node.ancestors("ul, ol")
    marker = "ol" == lists[0]&.name ? "1. " : "- "
    indent = (" " * marker.size) * [1, lists.size].max
    suffix = node == node.parent.elements[-1] ? "" : "\n"

    text.gsub!(/\n{2,}/, "\n\n")
    text.gsub!(/^(?!\s*$)/, indent)
    text.lstrip!

    "#{marker}#{text}#{suffix}"
  end

  EMPHASES = %w[i em]
  EMPHASES.each do |tag|
    define_method("visit_#{tag}") do |node|
      text = traverse(node)

      return "" if text.empty?
      return " " if text.blank?
      return "<#{tag}>#{text}</#{tag}>" if text["\n"] || (text["*"] && text["_"])

      prefix = text[0][" "]
      suffix = text[-1][" "] if text.size > 1
      wrap = text["*"] ? "_" : "*"

      "#{prefix}#{wrap}#{text.strip}#{wrap}#{suffix}"
    end
  end

  STRONGS = %w[b strong]
  STRONGS.each do |tag|
    define_method("visit_#{tag}") do |node|
      text = traverse(node)

      return "" if text.empty?
      return " " if text.blank?
      return "<#{tag}>#{text}</#{tag}>" if text["\n"] || (text["*"] && text["_"])

      prefix = text[0][" "]
      suffix = text[-1][" "] if text.size > 1
      wrap = text["*"] ? "__" : "**"

      "#{prefix}#{wrap}#{text.strip}#{wrap}#{suffix}"
    end
  end

  STRIKES = %w[s strike]
  STRIKES.each do |tag|
    define_method("visit_#{tag}") do |node|
      text = traverse(node)

      return "" if text.empty?
      return " " if text.blank?
      return "<#{tag}>#{text}</#{tag}>" if text["\n"] || text["~~"]

      prefix = text[0][" "]
      suffix = text[-1][" "] if text.size > 1

      "#{prefix}~~#{text.strip}~~#{suffix}"
    end
  end

  def visit_text(node)
    if @within_html_block
      node.to_html
    else
      node.text
    end
  end

  HTML5_BLOCK_ELEMENTS = %w[
    article
    aside
    details
    dialog
    figcaption
    figure
    footer
    header
    main
    nav
    section
  ]
  def block?(node)
    return false if !node
    node.description&.block? || HTML5_BLOCK_ELEMENTS.include?(node.name)
  end

  def fragment_document
    @fragment_document ||= Nokogiri::HTML5::DocumentFragment.parse("").document
  end

  def create_element(tag, inner_html = nil, attributes = {})
    element = fragment_document.create_element(tag, nil, attributes)
    element.inner_html = inner_html if inner_html
    element
  end
end
