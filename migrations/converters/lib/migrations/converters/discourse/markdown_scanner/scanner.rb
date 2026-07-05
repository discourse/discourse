# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # Walks Discourse Markdown and replaces detected constructs (outside code)
        # with whatever the given block returns for each detected node.
        class Scanner
          TRIGGER_CHARS = Set.new(["@", "[", "!"]).freeze
          private_constant :TRIGGER_CHARS

          # @param detectors [Array<Detectors::Base>] detector instances in priority
          #   order.
          # @yieldparam node the detected AST node; the block returns its replacement.
          def initialize(detectors:, &on_node)
            @detectors = detectors
            @on_node = on_node
          end

          # @param input [String]
          # @return [String] the input with detected constructs replaced.
          def scan(input)
            @code_tracker = CodeBlockTracker.new
            @result = +""
            @pos = 0
            @input = input.to_s
            @line_start = true

            scan_input
            @result
          end

          private

          def scan_input
            while @pos < @input.length
              if @line_start
                next if advance_code_boundary(:check_fenced_boundary)
                next if advance_code_boundary(:check_indented_boundary)
              end

              # Read the character once and reuse it — `String#[]` allocates a new
              # one-character string each time, and this is the hot loop.
              char = @input[@pos]

              if char == "`"
                new_pos = @code_tracker.check_inline_boundary(@input, @pos)
                if new_pos
                  @result << @input[@pos...new_pos]
                  @pos = new_pos
                  @line_start = false
                  next
                end
              end

              if @code_tracker.in_code?
                @result << char
                @line_start = char == "\n"
                @pos += 1
                next
              end

              if TRIGGER_CHARS.include?(char)
                match = detect_at_position
                if match
                  handle_match(match)
                  next
                end
              end

              @result << char
              @line_start = char == "\n"
              @pos += 1
            end
          end

          def advance_code_boundary(method)
            new_pos = @code_tracker.public_send(method, @input, @pos, line_start: true)
            return false unless new_pos

            @result << @input[@pos...new_pos]
            @pos = new_pos
            @line_start = true
            true
          end

          def detect_at_position
            @detectors.each do |detector|
              match = detector.detect(@input, @pos)
              return match if match
            end
            nil
          end

          def handle_match(match)
            @result << @on_node.call(match.node).to_s
            @pos = match.end_pos
            @line_start = false
          end
        end
      end
    end
  end
end
