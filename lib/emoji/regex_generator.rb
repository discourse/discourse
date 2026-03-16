# frozen_string_literal: true

# Generates an optimized JavaScript-compatible regex pattern that matches
# all Unicode emoji sequences from Emoji.unicode_replacements.
#
# The generated regex uses:
# - Character class ranges for contiguous codepoints (e.g., \u2600-\u2604)
# - Trie-based grouping for shared prefixes (e.g., \uD83D(?:...))
# - Optional markers for variation selectors and skin tones
#
# Usage:
#   Emoji::RegexGenerator.generate  # => "☻|♡|[#*0-9]\\uFE0F?..."
#
class Emoji
  module RegexGenerator
    # Characters added beyond the standard Unicode emoji set
    EXTRA_PATTERNS = %w[☻ ♡].freeze

    module_function

    def generate
      sequences = build_sequences
      trie = build_trie(sequences)
      pattern = trie_to_pattern(trie)
      extras = EXTRA_PATTERNS.join("|")
      "#{extras}|#{pattern}"
    end

    VARIATION_SELECTOR = 0xFE0F

    # Convert emoji keys to sorted UTF-16 code unit sequences.
    # Also adds FE0F (variation selector) variants so the regex matches
    # emoji typed with or without the variation selector (e.g. ☠ and ☠️).
    def build_sequences
      sequences = []
      Emoji.unicode_replacements.each_key do |key|
        codepoints = key.codepoints
        seq = to_utf16_code_units(codepoints)
        sequences << seq
        sequences << seq + [VARIATION_SELECTOR] unless codepoints.last == VARIATION_SELECTOR
      end
      sequences.sort!.uniq!
      sequences
    end

    # Convert Unicode codepoints to JavaScript UTF-16 code units (surrogate pairs for > 0xFFFF)
    def to_utf16_code_units(codepoints)
      units = []
      codepoints.each do |cp|
        if cp > 0xFFFF
          cp -= 0x10000
          units << (0xD800 + (cp >> 10))
          units << (0xDC00 + (cp & 0x3FF))
        else
          units << cp
        end
      end
      units
    end

    # Build a trie (nested hash) from sequences of code units
    # Each leaf is marked with :end => true
    def build_trie(sequences)
      trie = {}
      sequences.each do |seq|
        node = trie
        seq.each do |unit|
          node[unit] ||= {}
          node = node[unit]
        end
        node[:end] = true
      end
      trie
    end

    # Convert a trie node to an optimized regex pattern string
    def trie_to_pattern(node)
      return nil if node.empty? || (node.keys == [:end])

      children = node.reject { |k, _| k == :end }
      return nil if children.empty?

      is_optional = node[:end] # This node is also a valid endpoint

      alternatives = build_alternatives(children)

      result =
        if alternatives.size == 1
          alternatives.first
        else
          "(?:#{alternatives.join("|")})"
        end

      result = "(?:#{result})?" if is_optional && children.size > 0
      result
    end

    # Group children by shared structure to produce compact alternatives
    def build_alternatives(children)
      # Separate children into "terminal" (leaf after this unit) and "continuing"
      terminal_units = []
      continuing = {}

      children.each do |unit, child|
        child_keys = child.reject { |k, _| k == :end }
        if child_keys.empty? && child[:end]
          terminal_units << unit
        else
          continuing[unit] = child
        end
      end

      alternatives = []

      # Terminal units can be combined into a character class
      alternatives << char_class(terminal_units) if terminal_units.any?

      # Group continuing children by their subtree pattern for factoring
      # e.g., if multiple units lead to the same suffix pattern, group them
      by_suffix = {}
      continuing.each do |unit, child|
        suffix = trie_to_pattern(child)
        is_also_end = child[:end]
        key = [suffix, is_also_end]
        by_suffix[key] ||= []
        by_suffix[key] << unit
      end

      by_suffix.each do |(suffix, _is_also_end), units|
        prefix = char_class(units)
        if suffix
          if units.size > 1
            alternatives << "#{prefix}#{suffix}"
          else
            # Single unit prefix — no need for extra grouping
            alternatives << "#{escape_unit(units.first)}#{suffix}"
          end
        else
          alternatives << prefix
        end
      end

      alternatives
    end

    # Build a character class or single escape from a set of code units
    def char_class(units)
      return escape_unit(units.first) if units.size == 1

      # Find contiguous ranges
      sorted = units.sort
      ranges = []
      range_start = sorted.first
      range_end = sorted.first

      sorted
        .drop(1)
        .each do |u|
          if u == range_end + 1
            range_end = u
          else
            ranges << [range_start, range_end]
            range_start = u
            range_end = u
          end
        end
      ranges << [range_start, range_end]

      parts =
        ranges.map do |s, e|
          if s == e
            escape_unit(s)
          elsif e == s + 1
            "#{escape_unit(s)}#{escape_unit(e)}"
          else
            "#{escape_unit(s)}-#{escape_unit(e)}"
          end
        end

      "[#{parts.join}]"
    end

    # Escape a single UTF-16 code unit for use in a JS regex string
    def escape_unit(unit)
      if unit < 0x80 && unit.chr.match?(/[a-zA-Z0-9 ]/)
        # Printable ASCII that's safe in regex
        unit.chr
      elsif unit < 0x80
        # ASCII symbols — some need escaping in regex
        case unit.chr
        when "#", "*", ".", "+", "?", "(", ")", "[", "]", "{", "}", "\\", "^", "$", "|"
          "\\#{unit.chr}"
        else
          unit.chr
        end
      else
        format("\\u%04X", unit)
      end
    end
  end
end
