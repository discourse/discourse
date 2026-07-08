# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # Walks Discourse Markdown and replaces detected constructs (outside code)
        # with whatever the given block returns for each detected node.
        #
        # The walk works entirely in BYTE offsets, not character indices. CRuby keeps
        # no character-index cache, so on a string with any multibyte character
        # `str[pos]`, `str.index(re, pos)` and `re.match(str, pos)` walk bytes from
        # the start to locate character `pos` — O(pos) per call. Doing dozens of
        # indexed calls per post that way made umlaut-heavy bodies scan ~2x slower
        # than ASCII. Byte offsets make every positioning O(1) regardless of content,
        # and make the byte-wise look-backs correct by construction.
        #
        # Every byte offset the walk touches lands on a character boundary: jumps land
        # on regex-match starts, single-character advances step over an ASCII trigger
        # (one byte), matches advance by their byte length, and the code tracker's
        # returns come from `byteindex`/ASCII scans. `byteindex` raises `IndexError` on
        # an off-boundary offset, so a logic bug here raises instead of producing a
        # wrong result.
        class Scanner
          # Presence gate. Every construct we extract contains an
          # `@` (mention), a `[` (quote, attachment, and an image's `![`), a `#`
          # (hashtag), or the `uploads/` segment of a full-URL upload — so a body
          # with none of those can't have one and skips the walk. `#` is included
          # because it's rare in plain prose. `!` and the bare-URL triggers are
          # deliberately not gates on their own: they're common characters, and each
          # extractable construct they start also carries one of these signals.
          MAYBE_EMBED = %r{[@\[#]|uploads/}
          private_constant :MAYBE_EMBED

          # @param detectors [Array<Detectors::Base>] detector instances in priority
          #   order; each declares the characters it can match at (`#triggers`).
          # @param extra_gate [Regexp, nil] an extra presence-gate alternative OR'd
          #   into {MAYBE_EMBED}, so a detector that's only wired in for some runs
          #   (the custom-emoji `:name:` shape) doesn't widen every run's gate.
          # @yieldparam node the detected AST node; the block returns its replacement.
          def initialize(detectors:, extra_gate: nil, &on_node)
            @on_node = on_node
            @gate = extra_gate ? Regexp.union(MAYBE_EMBED, extra_gate) : MAYBE_EMBED

            # Detectors keyed by trigger BYTE (each trigger character's ordinal),
            # preserving priority order. Keying by byte lets the walk read the current
            # character as an Integer (`getbyte`) and dispatch without allocating a
            # one-character string per stop. The walk visits every position anything
            # could react to, so a position must only run the detectors that can match
            # there — asking every detector at every trigger was a measurable share of
            # a whole conversion.
            @dispatch = {}
            detectors.each do |detector|
              detector.triggers.each { |char| (@dispatch[char.ord] ||= []) << detector }
            end
            @dispatch.each_value(&:freeze)
            @dispatch.freeze

            # Everything the walk must stop at: the trigger characters, a backtick
            # (possible inline-code delimiter) and the newline that re-arms the
            # line-start code checks. Runs of anything else are skipped in one
            # regex jump and appended as one slice.
            chars = (detectors.flat_map(&:triggers) + ["`", "\n"]).uniq
            @interesting = Regexp.new("[#{chars.map { |char| Regexp.escape(char) }.join}]")
          end

          # @param input [String]
          # @return [String] the input with detected constructs replaced.
          def scan(input)
            input = input.to_s

            # Most posts have no embed at all — skip the walk (and every allocation
            # it makes) and return the body untouched.
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

          # Inside code only a backtick (a possible inline-code closer) or a newline
          # (which re-arms the line-start checks) can change anything.
          CODE_INTERESTING = /[`\n]/
          private_constant :CODE_INTERESTING

          def scan_input
            length = @input.bytesize

            while @pos < length
              if @line_start
                next if advance_code_boundary(:check_fenced_boundary)
                next if advance_code_boundary(:check_indented_boundary)
              end

              # Jump straight to the next position anything can react to; the run
              # of plain characters before it is appended as one slice. Walking
              # char-by-char instead costs a one-character string per position.
              interesting = @code_tracker.in_code? ? CODE_INTERESTING : @interesting
              index = @input.byteindex(interesting, @pos)

              unless index
                @result << @input.byteslice(@pos..)
                @pos = length
                break
              end

              if index > @pos
                @result << @input.byteslice(@pos...index)
                @pos = index
                @line_start = false
              end

              byte = @input.getbyte(@pos)

              if byte == 0x60 # 0x60 = backtick
                new_pos = @code_tracker.check_inline_boundary(@input, @pos)
                if new_pos
                  @result << @input.byteslice(@pos...new_pos)
                  @pos = new_pos
                  @line_start = false
                  next
                end
              end

              if !@code_tracker.in_code? && (candidates = @dispatch[byte])
                match = detect_at_position(candidates, byte)
                if match
                  handle_match(match)
                  next
                end
              end

              # A failed trigger, backtick or newline. Every interesting byte is
              # ASCII, so appending the byte as a codepoint reproduces the one
              # character without allocating a slice for it.
              @result << byte
              @line_start = byte == 0x0a # 0x0a = newline
              @pos += 1
            end
          end

          def advance_code_boundary(method)
            new_pos = @code_tracker.public_send(method, @input, @pos, line_start: true)
            return false unless new_pos

            @result << @input.byteslice(@pos...new_pos)
            @pos = new_pos
            @line_start = true
            true
          end

          def detect_at_position(candidates, byte)
            candidates.each do |detector|
              match = detector.detect(@input, @pos, byte)
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
