# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        class EngineScanner
          # The byte-domain machinery the count-matching pass and the substitution pass
          # share: finding a value's occurrences in the raw, validating an
          # occurrence's boundaries, turning an occurrence into a
          # match that covers the whole construct, and splicing the accepted matches.
          # Everything reads `@input`, `@line_starts` and `@scanner`, which the
          # including pass sets up.
          #
          # Occurrence lookups answer from per-body indexes that are built
          # lazily and at most once, so a body with many distinct engine
          # values does not pay one search walk per value.
          module Locating
            include Constructs::Boundaries

            # A matched raw occurrence: where it starts and how many bytes
            # the matched reading spans there (an alternate URL reading can
            # differ in length from the engine's value).
            Occurrence = Data.define(:offset, :length)

            URL_BYTES = [*"a".."z", *"A".."Z", *"0".."9", "/"].to_set(&:ord).freeze
            TRAILING_PUNCTUATION = ".?#&=%~_-".bytes.to_set.freeze

            EMPTY_OCCURRENCES = [].freeze
            private_constant :EMPTY_OCCURRENCES

            # A link's `[`/`!` anchor is searched backwards from its
            # destination; the construct grammars cap a label around a thousand
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

            # Every mention/hashtag/emoji construct in the body, found in ONE
            # pass over the trigger bytes and keyed like {#index_key}. The
            # constructs validate boundaries and gate on the source's name sets,
            # so an entry here IS a construct match with exactly that text.
            def probe_index
              @probe_index ||=
                begin
                  index = {}
                  stop = @scanner.probe_stop
                  if stop
                    pos = 0
                    while (offset = @input.byteindex(stop, pos))
                      byte = @input.getbyte(offset)
                      kind, construct = @scanner.probe_dispatch[byte]
                      if kind && (match = construct.detect(@input, offset, byte))
                        length = match.end_pos - offset
                        key = index_key(kind, @input.byteslice(offset, length))
                        (index[key] ||= []) << Occurrence.new(offset:, length:)
                      end
                      pos = offset + 1
                    end
                  end
                  index
                end
            end

            # Hashtags are keyed by normalized text: the engine reports a
            # hashtag's ref casefolded while the raw spells the author's form
            # (`#Support`), and normalizing both sides the same way
            # ({NameNormalizer}) also matches a decomposed raw spelling against
            # the composed name it denotes. Mention and emoji token content
            # preserves the raw's own bytes, and folding those would conflate
            # `@Bob` with `@bob`, two distinct token values.
            def index_key(kind, text)
              kind == :hashtag ? [kind, Migrations::NameNormalizer.normalize(text)] : [kind, text]
            end

            def probed_occurrences(kind, value)
              probe_index[index_key(kind, value)] || EMPTY_OCCURRENCES
            end

            # The occurrences of a URL value in `range` — every reading (the
            # engine normalizes URLs: percent-encoding, linkify adding a
            # scheme to a bare-domain autolink) unioned and deduplicated. The
            # readings must be counted as ONE union, never independently: with
            # `` `http://host/t/5` `` in code and the schemeless spelling in
            # prose, the scheme-ful reading alone counts 1 and would match
            # the code span — the union counts 2 against the engine's 1 and
            # refuses, so the substitution pass can confirm which span is live.
            #
            # Memoized per (value, range): a mapless block, the global
            # fallback and the substitution pass all ask for the same whole-body
            # range and share one walk. The search itself is still one scan
            # per value — `EngineScanner::MAX_URL_VALUES` bounds how many
            # distinct URL values a body may bring here.
            #
            # @return [Array(Array<Occurrence>, Boolean)] the sorted spans and
            #   whether two distinct spans overlap — overlapping spellings
            #   cannot be attributed by counting, so count matching refuses them
            #   (the substitution pass still probes each span individually).
            def url_spans(value, range)
              @url_spans ||= {}
              @url_spans[[value, range]] ||= begin
                spans = []
                url_readings_for(value).each { |reading| collect_url_spans(reading, range, spans) }
                spans.uniq!
                spans.sort_by!(&:offset)
                overlapping =
                  spans.each_cons(2).any? { |left, right| right.offset < left.offset + left.length }
                [spans, overlapping].freeze
              end
            end

            def url_readings_for(value)
              @url_readings ||= {}
              @url_readings[value] ||= url_readings(value)
            end

            def collect_url_spans(reading, range, spans)
              length = reading.bytesize
              return if length == 0

              pos = range.begin
              limit = range.end - length
              while pos <= limit && (index = @input.byteindex(reading, pos))
                break if index > limit

                spans << Occurrence.new(offset: index, length:) if url_occurrence?(index, length)
                pos = index + 1
              end
            end

            # The `[offset, length]` pairs of every spelling of `value` that
            # sits in destination position on a reference-definition line
            # (`[label]: <url>`). Memoized per value; both passes ask for it —
            # count matching to accept a definition serving several links, a
            # substitution check to accept the matching token delta.
            def definition_offsets(value)
              @definition_offsets ||= {}
              @definition_offsets[value] ||= begin
                offsets = Set.new
                url_readings_for(value).each do |reading|
                  pattern =
                    /^ {0,3}\[[^\]\n]*\]:[^\S\n]*<?(?<dest>#{Regexp.escape(reading)})>?(?=\s|\z)/
                  pos = 0
                  while (match = pattern.match(@input, pos))
                    offsets << [match.byteoffset(:dest).first, reading.bytesize]
                    pos = match.end(0)
                  end
                end
                offsets.freeze
              end
            end

            def occurrences_within(occurrences, range)
              occurrences.select do |occurrence|
                occurrence.offset >= range.begin &&
                  occurrence.offset + occurrence.length <= range.end
              end
            end

            # Byte offsets of every construct-capable character reference, one
            # scan for the whole body, so each region precondition is a binary
            # search instead of a byteslice plus a fresh scan.
            def entity_offsets
              @entity_offsets ||= @scanner.construct_capable_entity_offsets(@input)
            end

            def entity_in?(range)
              index = entity_offsets.bsearch_index { |offset| offset >= range.begin }
              !index.nil? && entity_offsets[index] < range.end
            end

            # The construct match behind an indexed occurrence. The index was
            # built from construct matches, so this re-probe cannot miss unless
            # a pass got out of step with its own index — callers treat nil as
            # that inconsistency.
            def probe_match_at(kind, occurrence)
              construct =
                case kind
                when :mention
                  @scanner.mention_construct
                when :hashtag
                  @scanner.hashtag_construct
                when :emoji
                  @scanner.emoji_construct
                end
              match = construct.detect(@input, occurrence.offset, @input.getbyte(occurrence.offset))
              match if match && match.end_pos == occurrence.offset + occurrence.length
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
            # The walk descends byte by byte, so no anchor list is allocated.
            def anchor_match(occurrence)
              offset = occurrence.offset
              line = @line_starts.bsearch_index { |start| start > offset } || @line_starts.size
              from = [@line_starts[[line - 2, 0].max], offset - ANCHOR_WINDOW].max

              pos = offset - 1
              while pos >= from
                byte = @input.getbyte(pos)
                if byte == 0x5b && pos > from && @input.getbyte(pos - 1) == 0x21 # `![`
                  # The image's `!` outranks its `[`: the `[` alone also
                  # matches, as a link, and being nearer would otherwise
                  # capture `[alt](…)` out of `![alt](…)`.
                  match =
                    construct_match_at(pos - 1, occurrence) || construct_match_at(pos, occurrence)
                  return match if match
                  pos -= 2
                elsif byte == 0x5b || byte == 0x21 # `[` `!`
                  match = construct_match_at(pos, occurrence)
                  return match if match
                  pos -= 1
                else
                  pos -= 1
                end
              end

              # The occurrence itself, as a bare URL. Linkify can take
              # trailing bytes no URL grammar accepts (a stray backtick or
              # backslash, punctuation, non-ASCII text glued to the URL) into
              # the href, so the matched occurrence may run past what a
              # construct can take. Leaving exactly those bytes literal is
              # correct — core will re-linkify both after resolution. A word
              # byte in the uncovered tail disqualifies the match: there the
              # match stopped inside the URL proper, and replacing a prefix
              # of a longer URL would leave its tail behind as text.
              construct_match_at(offset, occurrence, allow_prefix: true)
            end

            # A confirmed occurrence that is its own whole construct: a bare
            # schemeless domain (linkify links it, but no construct grammar has
            # a byte to trigger on) or a reference definition's destination.
            # The engine's href carries the scheme the route parses from; the
            # span replaced is exactly the raw spelling. The confirmation came from
            # count matching or a substitution check, so "is this really a link here?" is
            # already answered — only the linkify opening boundary is
            # re-checked, mirroring what core requires ahead of a bare URL.
            def bare_value_match(value, occurrence)
              return nil unless bare_url_boundary_before?(@input, occurrence.offset)

              raw_spelling = @input.byteslice(occurrence.offset, occurrence.length)
              node = @scanner.bare_url_node(route_url: value, url: raw_spelling)
              return nil if node.nil?

              Constructs::Match.new(
                start_pos: occurrence.offset,
                end_pos: occurrence.offset + occurrence.length,
                node:,
              )
            end

            def construct_match_at(anchor, occurrence, allow_prefix: false)
              byte = @input.getbyte(anchor)
              occurrence_end = occurrence.offset + occurrence.length
              @scanner.url_dispatch[byte]&.each do |construct|
                match = construct.detect(@input, anchor, byte)
                next if match.nil?
                next unless match.start_pos <= occurrence.offset
                if match.end_pos >= occurrence_end
                  return match
                elsif allow_prefix && match.end_pos > occurrence.offset &&
                      swallowed_tail?(match.end_pos, occurrence_end)
                  return match
                end
              end
              nil
            end

            # Whether the occurrence bytes past the construct match are a
            # short wordless linkify tail — the only tail a match may leave
            # uncovered (see `anchor_match` and
            # `Constructs::Base::MAX_SWALLOWED_TAIL_BYTES`). Length matters as
            # much as content: linkify swallows a few bytes of punctuation,
            # never hundreds, and a long tail means the match stopped inside
            # the URL proper.
            def swallowed_tail?(from, to)
              return false if to - from > Constructs::Base::MAX_SWALLOWED_TAIL_BYTES

              (from...to).none? do |pos|
                byte = @input.getbyte(pos)
                byte == 0x5f || (byte >= 0x30 && byte <= 0x39) || (byte >= 0x41 && byte <= 0x5a) ||
                  (byte >= 0x61 && byte <= 0x7a)
              end
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
