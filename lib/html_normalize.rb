# frozen_string_literal: true
#
# this class is used to normalize html output for internal comparisons in specs
#
require 'oga'

class HtmlNormalize

  def self.normalize(html)
    parsed = Oga.parse_html(html.strip, strict: true)
    if parsed.children.length != 1
      puts parsed.children.count
      raise "expecting a single child"
    end
    new(parsed.children.first).format
  end

  SELF_CLOSE = Set.new(%w{area base br col command embed hr img input keygen line meta param source track wbr})

  BLOCK = Set.new(%w{
    html
    body
    aside
    p
    h1 h2 h3 h4 h5 h6
    ol ul
    address
    blockquote
    dl
    div
    fieldset
    form
    hr
    noscript
    table
    pre
  })

  def initialize(doc)
    @doc = doc
  end

  def format
    buffer = String.new
    dump_node(@doc, 0, buffer)
    buffer.strip!
    buffer
  end

  def inline?(node)
    Oga::XML::Text === node || !BLOCK.include?(node.name.downcase)
  end

  def dump_node(node, indent=0, buffer)

    if Oga::XML::Text === node
      if node.parent&.name
        buffer << node.text
      end
      return
    end

    name = node.name.downcase

    block = BLOCK.include?(name)

    buffer << " " * indent * 2 if block

    buffer << "<" << name

    attrs = node&.attributes
    if (attrs && attrs.length > 0)
      attrs.sort!{|x,y| x.name <=> y.name}
      attrs.each do |a|
        buffer << " "
        buffer << a.name
        buffer << "='"
        buffer << a.value
        buffer << "'"
      end
    end

    buffer << ">"

    if block
      buffer << "\n"
    end

    children = node.children
    children = trim(children) if block

    inline_buffer = nil

    children&.each do |child|
      if block && inline?(child)
        inline_buffer ||= String.new
        dump_node(child, indent+1, inline_buffer)
      else
        if inline_buffer
          buffer << " " * (indent+1) * 2
          buffer << inline_buffer.strip
          inline_buffer = nil
        else
          dump_node(child, indent+1, buffer)
        end
      end
    end

    if inline_buffer
      buffer << " " * (indent+1) * 2
      buffer << inline_buffer.strip
      inline_buffer = nil
    end

    if block
      buffer << "\n" unless buffer[-1] == "\n"
      buffer << " " * indent * 2
    end

    unless SELF_CLOSE.include?(name)
      buffer << "</" << name
      buffer << ">\n"
    end
  end

  def trim(nodes)
    start = 0
    finish = nodes.length

    nodes.each do |n|
      if Oga::XML::Text === n && n.text.blank?
        start += 1
      else
        break
      end
    end

    nodes.reverse_each do |n|
      if Oga::XML::Text === n && n.text.blank?
        finish -= 1
      else
        break
      end
    end

    nodes[start...finish]
  end


end
