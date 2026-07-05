# frozen_string_literal: true

require "markbridge"

module Migrations
  module Converters
    module Discourse
      # Single-pass scanner for Discourse Markdown that extracts specific constructs
      # (uploads, quote attributions, mentions) while leaving everything else — and,
      # crucially, anything inside fenced/indented/inline **code** — untouched.
      #
      # This is vendored from Markbridge 0.2.0's `Processors::DiscourseMarkdown`
      # (`Scanner` + `CodeBlockTracker` + the upload/mention detectors). That
      # Markdown-scanning logic is Discourse-specific and is being removed from
      # Markbridge, which keeps only the format-agnostic AST and renderer — so it
      # lives here now. We still rely on `Markbridge::AST::*` for the node types.
      #
      # The scanner walks the input character by character; on a successful match it
      # asks the supplied block for the replacement text (a placeholder token) and
      # skips past the matched span.
      module MarkdownScanner
        # A deferred quote attribution. Markbridge has no quote AST node of this
        # shape (its `AST::Quote` is a full block element), and only the opening
        # `[quote="…"]` carries the post/topic/user references that need remapping.
        QuoteAttribution = Data.define(:username, :post)

        module Detectors
          # Result of a successful detection.
          Match = Data.define(:start_pos, :end_pos, :node)

          # Base class for construct detectors.
          class Base
            # @return [Match, nil]
            def detect(input, pos)
              raise NotImplementedError, "#{self.class} must implement #detect"
            end

            private

            WORD_PATTERN = /\A[\w\-]*/
            private_constant :WORD_PATTERN

            def word_boundary?(input, pos)
              return true if pos.zero?

              !input[pos - 1].match?(/\w/)
            end

            # Extract a word starting at position. Caller must ensure pos is within
            # bounds (`pos <= input.length`).
            def extract_word(input, pos)
              input[pos..].match(WORD_PATTERN)[0]
            end
          end

          # Detects user and group mentions (`@name`). The mention *type* is decided
          # later by the converter's MentionResolver (it needs the source's groups
          # and `here_mention` setting), so the node just carries the name.
          class Mention < Base
            def detect(input, pos)
              return nil unless input[pos] == "@"
              return nil unless word_boundary?(input, pos)

              name = extract_word(input, pos + 1)
              return nil if name.empty?

              Match.new(
                start_pos: pos,
                end_pos: pos + 1 + name.length,
                node: Markbridge::AST::Mention.new(name:),
              )
            end
          end

          # Detects Discourse upload references (`upload://` URLs), both
          # `![alt|dims](upload://sha1.ext)` images and
          # `[file|attachment](upload://sha1.ext) (size)` attachments.
          class Upload < Base
            IMAGE_PATTERN =
              %r{\A!\[(?<alt>[^|\]]*)(?:\|(?<dimensions>[^\]]*))?\]\(upload://(?<url>[^)]+)\)}

            ATTACHMENT_PATTERN =
              %r{
              \A
              \[(?<filename>[^|\]]*)\|attachment\]
              \(upload://(?<url>[^)]+)\)
              (?:\s*\((?<size>[^)]+)\))?
            }xi

            def detect(input, pos)
              remaining = input[pos..]

              case input[pos]
              when "!"
                detect_image(remaining, pos)
              when "["
                detect_attachment(remaining, pos)
              end
            end

            private

            def detect_image(remaining, pos)
              match = IMAGE_PATTERN.match(remaining)
              return nil unless match

              sha1, filename = parse_upload_url(match[:url])
              alt = match[:alt]
              alt = nil if alt.empty?

              node =
                Markbridge::AST::Upload.new(
                  sha1:,
                  filename:,
                  alt:,
                  dimensions: match[:dimensions],
                  raw: match[0],
                )

              Match.new(start_pos: pos, end_pos: pos + match[0].length, node:)
            end

            def detect_attachment(remaining, pos)
              match = ATTACHMENT_PATTERN.match(remaining)
              return nil unless match

              sha1, = parse_upload_url(match[:url])

              node =
                Markbridge::AST::Upload.new(
                  sha1:,
                  filename: match[:filename],
                  type: :attachment,
                  size: match[:size],
                  raw: match[0],
                )

              Match.new(start_pos: pos, end_pos: pos + match[0].length, node:)
            end

            # URL format: `sha1.ext` or just `sha1`. Returns `[sha1, filename-or-nil]`.
            def parse_upload_url(url_part)
              sha1, _, ext = url_part.partition(".")
              [sha1, ext.empty? ? nil : url_part]
            end
          end

          # Detects only the opening tag of a Discourse quote (`[quote="…"]`); the
          # body and `[/quote]` stay in place, and any embeds inside the body are
          # still scanned. Returns nil for an unattributed `[quote]`.
          class Quote < Base
            OPENING = /\A\[quote="(?<attribution>[^"\]]*)"\]/

            def detect(input, pos)
              return nil unless input[pos] == "["

              match = OPENING.match(input[pos..])
              return nil unless match

              username, post = parse_attribution(match[:attribution])
              return nil if username.nil?

              Match.new(
                start_pos: pos,
                end_pos: pos + match[0].length,
                node: QuoteAttribution.new(username:, post:),
              )
            end

            private

            # The username is the explicit `username:` value when present (Discourse
            # uses it when the display name differs), else the leading bare token.
            def parse_attribution(string)
              username = post = name = nil

              string
                .split(",")
                .map(&:strip)
                .each_with_index do |part, index|
                  case part
                  when /\Apost:(\d+)\z/
                    post = Regexp.last_match(1)
                  when /\Atopic:\d+\z/
                    next
                  when /\Ausername:(.+)\z/
                    username = Regexp.last_match(1)
                  else
                    name = part if index.zero? && !part.empty?
                  end
                end

              [username || name, post]
            end
          end
        end

        # Tracks whether the current position is inside a code block: fenced
        # (``` ``` ``` / `~~~`), indented (4+ spaces or a tab), or inline (`` ` ``).
        class CodeBlockTracker
          attr_reader :in_fenced_block, :in_indented_block, :in_inline_code

          def initialize
            @in_fenced_block = false
            @in_indented_block = false
            @in_inline_code = false
          end

          def in_code?
            @in_fenced_block || @in_indented_block || @in_inline_code
          end

          # @return [Integer, nil] end position after a fence, or nil.
          def check_fenced_boundary(input, pos, line_start:)
            return nil unless line_start

            input_length = input.length
            scan_pos = skip_leading_spaces(input, pos)
            fence_char = input[scan_pos]
            return nil unless fence_char == "`" || fence_char == "~"

            fence_length, scan_pos = count_fence_chars(input, scan_pos, fence_char, input_length)
            return nil if fence_length < 3

            if @in_fenced_block
              try_close_fence(input, scan_pos, fence_char, fence_length, input_length)
            else
              open_fence(input, scan_pos, fence_char, fence_length, input_length)
            end
          end

          # @return [Integer, nil] end position after an indented-code line, or nil.
          def check_indented_boundary(input, pos, line_start:)
            return nil unless line_start
            return nil if @in_fenced_block

            input_length = input.length
            line_end = input.index("\n", pos) || input_length
            line_content = input[pos...line_end]
            is_blank = line_content.match?(/\A\s*\z/)
            has_code_indent = line_content.start_with?("    ") || line_content.start_with?("\t")

            if @in_indented_block
              if is_blank || has_code_indent
                pos_after_line(line_end, input_length)
              else
                @in_indented_block = false
                nil
              end
            elsif has_code_indent
              @in_indented_block = true
              pos_after_line(line_end, input_length)
            end
          end

          # @return [Integer, nil] end position after inline code delimiter, or nil.
          def check_inline_boundary(input, pos)
            return nil if @in_fenced_block || @in_indented_block
            return nil if input[pos] != "`"

            input_length = input.length
            if @in_inline_code
              try_close_inline(input, pos, input_length)
            else
              open_inline(input, pos, input_length)
            end
          end

          private

          def skip_leading_spaces(input, pos)
            scan_pos = pos
            spaces = 0
            while spaces < 3 && input[scan_pos] == " "
              spaces += 1
              scan_pos += 1
            end
            scan_pos
          end

          def count_fence_chars(input, scan_pos, fence_char, input_length)
            fence_length = 0
            while scan_pos < input_length && input[scan_pos] == fence_char
              fence_length += 1
              scan_pos += 1
            end
            [fence_length, scan_pos]
          end

          def try_close_fence(input, scan_pos, fence_char, fence_length, input_length)
            return nil unless fence_char == @fence_char && fence_length >= @fence_length

            scan_pos += 1 while scan_pos < input_length && input[scan_pos] == " "
            return nil unless scan_pos >= input_length || input[scan_pos] == "\n"

            @in_fenced_block = false
            pos_after_line(scan_pos, input_length)
          end

          def open_fence(input, scan_pos, fence_char, fence_length, input_length)
            scan_pos += 1 while scan_pos < input_length && input[scan_pos] != "\n"

            @in_fenced_block = true
            @fence_char = fence_char
            @fence_length = fence_length
            pos_after_line(scan_pos, input_length)
          end

          def try_close_inline(input, pos, input_length)
            delimiter_length = @inline_delimiter.length
            return nil unless input[pos, delimiter_length] == @inline_delimiter

            next_pos = pos + delimiter_length
            return nil if next_pos < input_length && input[next_pos] == "`"

            @in_inline_code = false
            next_pos
          end

          def open_inline(input, pos, input_length)
            delimiter_start = pos
            pos += 1 while pos < input_length && input[pos] == "`"

            @inline_delimiter = input[delimiter_start...pos]
            @in_inline_code = true
            pos
          end

          def pos_after_line(line_end, input_length)
            line_end < input_length ? line_end + 1 : line_end
          end
        end

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

              if @input[@pos] == "`"
                new_pos = @code_tracker.check_inline_boundary(@input, @pos)
                if new_pos
                  @result << @input[@pos...new_pos]
                  @pos = new_pos
                  @line_start = false
                  next
                end
              end

              if @code_tracker.in_code?
                @result << @input[@pos]
                @line_start = @input[@pos] == "\n"
                @pos += 1
                next
              end

              char = @input[@pos]
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
