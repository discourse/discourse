# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # Walks Discourse Markdown and replaces detected constructs (outside code)
        # with whatever the given block returns for each detected node.
        class Scanner
          # Per-position triggers: at one of these the loop asks the detectors to
          # match. `!` is here because an image is detected at its leading `!`; `h`
          # and `/` because a bare (unbracketed) upload URL starts with `http`, `//`
          # or a root-relative `/…`; `#` starts a hashtag.
          TRIGGER_CHARS = Set.new(["@", "[", "!", "h", "/", "#"]).freeze
          private_constant :TRIGGER_CHARS

          # Presence gate for the fast path. Every construct we extract contains an
          # `@` (mention), a `[` (quote, attachment, and an image's `![`), a `#`
          # (hashtag), or the `uploads/` segment of a full-URL upload — so a body
          # with none of those can't have one and skips the walk. `#` earns its place
          # because it's rare in plain prose. `!` and the bare-URL triggers are
          # deliberately not gates on their own: they're common characters, and each
          # extractable construct they start also carries one of these signals.
          MAYBE_EMBED = %r{[@\[#]|uploads/}
          private_constant :MAYBE_EMBED

          # @param detectors [Array<Detectors::Base>] detector instances in priority
          #   order.
          # @param extra_triggers [Array<String>] trigger characters a caller's
          #   detectors add on top of {TRIGGER_CHARS}. Kept optional so a detector
          #   that's only wired in for some runs (the custom-emoji `:`) doesn't make
          #   every post pay for its trigger.
          # @param extra_gate [Regexp, nil] an extra presence-gate alternative OR'd
          #   into {MAYBE_EMBED}, for the same reason.
          # @yieldparam node the detected AST node; the block returns its replacement.
          def initialize(detectors:, extra_triggers: [], extra_gate: nil, &on_node)
            @detectors = detectors
            @on_node = on_node
            @triggers = extra_triggers.empty? ? TRIGGER_CHARS : (TRIGGER_CHARS + extra_triggers)
            @gate = extra_gate ? Regexp.union(MAYBE_EMBED, extra_gate) : MAYBE_EMBED
          end

          # @param input [String]
          # @return [String] the input with detected constructs replaced.
          def scan(input)
            input = input.to_s

            # Most posts have no embed at all — skip the character walk (and every
            # allocation it makes) and hand the body back untouched.
            return input unless input.match?(@gate)

            @code_tracker = CodeBlockTracker.new
            @result = +""
            @pos = 0
            @input = input
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

              if @triggers.include?(char)
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
