# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # Walks Markdown the {TierGate} classified as all-prose: no code fences,
        # no indented, `[code]` or `<pre>` blocks, no inline code, no CR line
        # endings, no link syntax, no entity that could spell a construct — the
        # gate's danger checks exclude every one of them. On such input the code
        # machinery {Scanner} carries is provably a no-op, so this walk skips it:
        # jump from trigger to trigger, ask the detectors, splice. Output equals
        # {Scanner}'s for any input in that class (asserted by spec); classifying
        # first just avoids paying for block tracking the input cannot need.
        #
        # Positions are byte offsets throughout, for the same O(1)-positioning
        # reasons documented on {Scanner}.
        class ProseScanner
          # @param detectors [Array<Detectors::Base>] detector instances in
          #   priority order — the same list a {Scanner} would take, so the two
          #   walks cannot disagree about a construct's shape.
          # @yieldparam node the detected AST node.
          # @yieldparam source [String] the verbatim matched slice. The block
          #   returns the node's replacement, or nil to decline the match.
          def initialize(detectors:, &on_node)
            @on_node = on_node

            @dispatch = {}
            detectors.each do |detector|
              detector.triggers.each { |char| (@dispatch[char.ord] ||= []) << detector }
            end
            @dispatch.each_value(&:freeze)
            @dispatch.freeze

            chars = detectors.flat_map(&:triggers).uniq
            @stop_pattern = Regexp.new("[#{chars.map { |char| Regexp.escape(char) }.join}]")
          end

          # @param input [String]
          # @return [String] the input with detected constructs replaced.
          def scan(input)
            result = +""
            pos = 0
            length = input.bytesize

            while pos < length
              index = input.byteindex(@stop_pattern, pos)

              unless index
                result << input.byteslice(pos..)
                break
              end

              result << input.byteslice(pos...index) if index > pos
              pos = index
              byte = input.getbyte(pos)

              match = detect_at(input, pos, byte)
              if match
                source = input.byteslice(match.start_pos...match.end_pos)
                replacement = match.node.nil? ? nil : @on_node.call(match.node, source)
                result << (replacement.nil? ? source : replacement.to_s)
                pos = match.end_pos
              else
                # Every stop byte is an ASCII trigger, so appending it as a
                # codepoint reproduces the character without a slice.
                result << byte
                pos += 1
              end
            end

            result
          end

          private

          def detect_at(input, pos, byte)
            candidates = @dispatch[byte]
            return nil unless candidates

            candidates.each do |detector|
              match = detector.detect(input, pos, byte)
              return match if match
            end
            nil
          end
        end
      end
    end
  end
end
