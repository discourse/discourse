# frozen_string_literal: true

# Parses a single CSS declaration value into a small tree using crass, so
# AppearanceStyles::Policy can check functions, colors and lengths without
# regular expressions. Anything that could end the value or pull in outside
# content (strings, url(), at-rules, blocks) fails to parse.
module AppearanceStyles
  class CssValue
    Node = Struct.new(:type, :value, :unit, :children, keyword_init: true)

    FORBIDDEN_TOKEN_TYPES = [
      :url,
      :bad_url,
      :string,
      :bad_string,
      :at_keyword,
      :semicolon,
      :"{",
      :"}",
      :"[",
      :"]",
      :cdo,
      :cdc,
      :unicode_range,
      :colon,
      :error,
    ].freeze

    class ParseError < StandardError
    end

    def self.parse(value)
      tokens = Crass::Tokenizer.tokenize(value.to_s)
      bad = tokens.find { |token| FORBIDDEN_TOKEN_TYPES.include?(token[:node]) }
      raise ParseError, "#{bad[:node]} is not allowed" if bad

      root = []
      stack = [root]

      tokens.each do |token|
        case token[:node]
        when :whitespace, :comment
          next
        when :function
          node = Node.new(type: :function, value: token[:value].downcase, children: [])
          stack.last << node
          stack << node.children
        when :"("
          node = Node.new(type: :group, value: "(", children: [])
          stack.last << node
          stack << node.children
        when :")"
          raise ParseError, "unbalanced parentheses" if stack.length == 1
          stack.pop
        when :dimension
          stack.last << Node.new(
            type: :dimension,
            value: token[:value],
            unit: token[:unit].downcase,
          )
        when :percentage
          stack.last << Node.new(type: :dimension, value: token[:value], unit: "%")
        when :number
          stack.last << Node.new(type: :number, value: token[:value])
        when :ident
          stack.last << Node.new(type: :ident, value: token[:value])
        when :hash
          stack.last << Node.new(type: :hash, value: token[:value])
        when :comma
          stack.last << Node.new(type: :comma)
        when :delim
          stack.last << Node.new(type: :delim, value: token[:value])
        else
          raise ParseError, "#{token[:node]} is not allowed"
        end
      end

      raise ParseError, "unbalanced parentheses" if stack.length != 1
      root
    end

    # Splits a node list on top-level commas.
    def self.split_commas(nodes)
      nodes
        .slice_when { |a, _b| a.type == :comma }
        .map { |part| part.reject { |n| n.type == :comma } }
    end

    def self.each_node(nodes, &block)
      nodes.each do |node|
        yield node
        each_node(node.children, &block) if node.children
      end
    end
  end
end
