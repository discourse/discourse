# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        class EngineScanner
          # The byte-domain machinery a certification pass and a trial pass
          # share: finding a value's occurrences in the raw, validating an
          # occurrence's boundaries, turning an occurrence into a
          # whole-construct detector match, and splicing the accepted matches.
          # Everything reads `@input`, `@line_starts` and `@scanner`, which the
          # including pass sets up.
          module Locating
            # A certified raw occurrence: where it starts and how many bytes
            # the certified reading spans there (an alternate URL reading can
            # differ in length from the engine's value).
            Occurrence = Data.define(:offset, :length)

            URL_BYTES = [*"a".."z", *"A".."Z", *"0".."9", "/"].to_set(&:ord).freeze
            TRAILING_PUNCTUATION = ".?#&=%~_-".bytes.to_set.freeze

            # A link's `[`/`!` anchor is searched backwards from its
            # destination; the detector grammars cap a label around a thousand
            # bytes, so a wider window cannot anchor anything and only costs
            # time on line-terminator-free bodies.
            ANCHOR_WINDOW = 2048

            private

            def build_line_index
              @line_starts = [0]
              offset = 0
              while (offset = @input.byteindex("\n", offset))
                offset += 1
                @line_starts << offset
              end
            end

            def occurrence_offsets(kind, reading, range)
              # A hashtag token's value is the lookup's casefolded ref, while
              # the raw spells the construct in the author's case (`#Support`),
              # so only that kind is searched case-insensitively — the detector
              # probe still validates every hit. Mention and emoji token
              # content preserves the raw's own bytes, and folding those would
              # conflate `@Bob` with `@bob`, two distinct token values.
              needle = kind == :hashtag ? /#{Regexp.escape(reading)}/i : reading
              occurrences = []
              length = reading.bytesize
              pos = range.begin
              limit = range.end - length

              while pos <= limit && (index = @input.byteindex(needle, pos))
                break if index > limit

                valid =
                  if kind == :url
                    url_occurrence?(index, length)
                  else
                    !probe_match(kind, reading, index).nil?
                  end
                occurrences << Occurrence.new(offset: index, length:) if valid
                pos = index + 1
              end

              occurrences
            end

            # For the probed kinds the detector itself validates an occurrence
            # — boundaries, name sets, everything — so an occurrence here IS a
            # detector match with exactly this value. A longer name matching at
            # the same offset (`@sam` inside `@samuel`) is a different
            # construct, not an occurrence of this one.
            def probe_match(kind, value, index)
              detector =
                case kind
                when :mention
                  @scanner.mention_detector
                when :hashtag
                  @scanner.hashtag_detector
                when :emoji
                  @scanner.emoji_detector
                end
              match = detector.detect(@input, index, @input.getbyte(index))
              match if match && match.end_pos == index + value.bytesize
            end

            # A URL occurrence must not be extendable into a longer URL: a
            # following URL character — or trailing punctuation with a URL
            # character after it, mirroring linkify's trailing-punctuation
            # stripping — means the raw spells a different, longer value. A
            # reading must also not sit right after `//`: that occurrence is
            # the tail of the scheme-ful spelling of some other value.
            def url_occurrence?(index, length)
              tail = index + length
              next_byte = @input.getbyte(tail)

              if next_byte
                return false if URL_BYTES.include?(next_byte)
                if TRAILING_PUNCTUATION.include?(next_byte)
                  after = @input.getbyte(tail + 1)
                  return false if after && URL_BYTES.include?(after)
                end
              end

              index < 2 || @input.byteslice(index - 2, 2) != "//"
            end

            def url_readings(value)
              readings = [value]
              decoded = percent_decode(value)
              readings << decoded if decoded && decoded != value
              bare = value.sub(%r{\Ahttps?://}i, "")
              if bare != value
                readings << bare
                bare_decoded = percent_decode(bare)
                readings << bare_decoded if bare_decoded && !readings.include?(bare_decoded)
              end
              readings
            end

            # Percent-decoding only — `CGI.unescape` would also turn `+` into a
            # space, which is form encoding, not URL encoding.
            def percent_decode(value)
              return value unless value.include?("%")

              decoded =
                value
                  .gsub(/%\h\h/) { |encoded| [encoded[1, 2]].pack("H2") }
                  .force_encoding(Encoding::UTF_8)
              decoded.valid_encoding? ? decoded : nil
            end

            # Try, nearest first, every possible syntax anchor between the
            # occurrence and the start of the previous line (a link's
            # destination may sit one line below its `[` — see
            # `Base::LINK_GAP`), then the occurrence itself as a bare URL.
            def anchor_match(occurrence)
              offset = occurrence.offset
              line = @line_starts.bsearch_index { |start| start > offset } || @line_starts.size
              from = [@line_starts[[line - 2, 0].max], offset - ANCHOR_WINDOW].max

              # Anchors are tried nearest-first (reverse of this ascending
              # list). An image's `![` pushes its positions swapped, so the
              # `!` is tried before its `[` — the `[` alone also matches, as
              # a link, and being nearer would otherwise capture `[alt](…)`
              # out of `![alt](…)`.
              anchors = []
              pos = from
              while pos < offset
                byte = @input.getbyte(pos)
                if byte == 0x21 && pos + 1 < offset && @input.getbyte(pos + 1) == 0x5b # `![`
                  anchors << pos + 1 << pos
                  pos += 2
                else
                  anchors << pos if byte == 0x21 || byte == 0x5b # `!` `[`
                  pos += 1
                end
              end

              anchors.reverse_each do |anchor|
                match = detector_match_at(anchor, occurrence)
                return match if match
              end

              # The occurrence itself, as a bare URL. Linkify can swallow a
              # trailing byte no URL grammar accepts (`` ` ``, `\`) and
              # percent-encode it into the href, so the certified occurrence
              # may run past what any detector can take; a detector match over
              # a prefix still rewrites the reference correctly and leaves the
              # odd byte literal, the way core will re-linkify both after
              # resolution.
              detector_match_at(offset, occurrence, allow_prefix: true)
            end

            def detector_match_at(anchor, occurrence, allow_prefix: false)
              byte = @input.getbyte(anchor)
              @scanner.url_dispatch[byte]&.each do |detector|
                match = detector.detect(@input, anchor, byte)
                next if match.nil?
                covered =
                  allow_prefix ? occurrence.offset + 1 : occurrence.offset + occurrence.length
                return match if match.start_pos <= occurrence.offset && match.end_pos >= covered
              end
              nil
            end

            def overlapping?(ordered)
              ordered.each_cons(2).any? { |left, right| right.start_pos < left.end_pos }
            end

            def splice(ordered)
              result = +""
              pos = 0

              ordered.each do |match|
                result << @input.byteslice(pos...match.start_pos) if match.start_pos > pos
                source = @input.byteslice(match.start_pos...match.end_pos)
                result << (@scanner.on_node.call(match.node, source) || source)
                pos = match.end_pos
              end
              result << @input.byteslice(pos..) if pos < @input.bytesize

              result
            end
          end
        end
      end
    end
  end
end
