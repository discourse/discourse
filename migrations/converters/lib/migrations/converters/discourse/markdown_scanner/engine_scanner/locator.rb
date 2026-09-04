# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        class EngineScanner
          # The byte-domain machinery for one body: finding a value's
          # occurrences in the raw, turning an occurrence into a match that
          # covers the whole construct, and splicing the accepted matches. One
          # locator serves both passes, so the line index, the folded copy, the
          # occurrence lists and the URL spans are built at most once.
          class Locator
            include Constructs::Boundaries

            # Where an occurrence starts and how many bytes the matched reading
            # spans there (an alternate URL reading can differ in length from
            # the engine's value).
            Occurrence = Data.define(:offset, :length)

            EMPTY_OCCURRENCES = [].freeze
            private_constant :EMPTY_OCCURRENCES

            # How far back a link's `[`/`!` anchor is searched from its
            # destination. The construct grammars cap a label around a thousand
            # bytes, so a wider window cannot anchor anything and only costs
            # time on line-terminator-free bodies.
            ANCHOR_WINDOW = 2048
            private_constant :ANCHOR_WINDOW

            def initialize(scanner, input)
              @scanner = scanner
              @input = input
              @occurrences = {}
              @url_spans = {}
              @url_readings = {}
              @definition_offsets = {}
              build_line_index
            end

            # The byte offset of every line start. The engine's maps count lines
            # after markdown-it normalized CR endings away, so only a CR-free
            # body may read regions off these.
            attr_reader :line_starts

            # Nil when the map names a line the body does not have.
            def region_range(map)
              return nil if map.nil?

              from = @line_starts[map[0]]
              return nil if from.nil?

              to = @line_starts[map[1]] || @input.bytesize
              from...to
            end

            # Every raw span that folds to `value`, for a mention, hashtag or
            # custom emoji: non-overlapping hits of the folded value in the
            # folded body, left to right, and nothing else — no boundary rule
            # and no name grammar (see {MarkdownScanner}). A leftmost scan for a
            # fixed-length needle returns a maximum set of disjoint hits, so the
            # count can only be too high. Memoized per value, one scan per
            # value.
            def folded_occurrences(kind, value)
              return EMPTY_OCCURRENCES if value.empty?

              @occurrences[[kind, value]] ||= begin
                spans = []
                pos = 0
                while (index = folded.text.byteindex(value, pos))
                  span = raw_span_of(index, value.bytesize, value)
                  if span
                    spans << Occurrence.new(offset: span[0], length: span[1])
                    pos = index + value.bytesize
                  else
                    # A hit that denotes no raw span is no occurrence, so the
                    # next one may start inside it.
                    pos = index + 1
                  end
                end
                spans.freeze
              end
            end

            # The occurrences of a URL value in `range` — every reading (the
            # engine normalizes URLs: percent-encoding, linkify adding a scheme
            # to a bare-domain autolink) unioned, deduplicated, and coalesced
            # where readings of one occurrence nest.
            #
            # The readings must be counted as ONE union, never independently:
            # with `` `http://host/t/5` `` in code and the schemeless spelling
            # in prose, the scheme-ful reading alone counts 1 and would match
            # the code span — the union counts 2 against the engine's 1 and
            # refuses, so the substitution pass can confirm which span is live.
            #
            # Memoized per (value, range), and bounded by
            # `EngineScanner::MAX_SCANNED_VALUES`.
            #
            # @return [Array<Occurrence>] sorted by offset
            def url_spans(value, range)
              @url_spans[[value, range]] ||= begin
                spans = []
                url_readings_for(value).each { |reading| collect_url_spans(reading, range, spans) }
                spans.uniq!
                # Outermost first, so coalescing keeps the widest reading of a
                # nested pair.
                spans.sort_by! { |span| [span.offset, -span.length] }
                coalesce(spans).freeze
              end
            end

            # The `[offset, length]` pairs of every spelling of `value` in
            # destination position on a reference-definition line (`[label]:
            # <url>`). Both passes ask for it — count matching to refuse a
            # definition serving several links, a substitution check to accept
            # the matching token delta.
            def definition_offsets(value)
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

            # One scan for the whole body, so each region precondition is a
            # binary search instead of a byteslice plus a fresh scan.
            def entity_offsets
              @entity_offsets ||= TierGate.construct_capable_entity_offsets(@input)
            end

            def entity_in?(range)
              index = entity_offsets.bsearch_index { |offset| offset >= range.begin }
              !index.nil? && entity_offsets[index] < range.end
            end

            # Built from the raw bytes, so the author's own spelling is recorded
            # (`@Bob`, `#Support::CATEGORY`, `:MYEMOJI:`) even though the engine
            # reported a folded value.
            def node_match(kind, occurrence)
              text = @input.byteslice(occurrence.offset, occurrence.length)
              Constructs::Match.new(
                start_pos: occurrence.offset,
                end_pos: occurrence.offset + occurrence.length,
                node: construct_for(kind).node_for(text),
              )
            end

            # Try, nearest first, every possible syntax anchor between the
            # occurrence and the start of the previous line (a link's
            # destination may sit one line below its `[` — see
            # `Base::LINK_GAP`), then the occurrence itself as a bare URL.
            def anchor_match(occurrence)
              offset = occurrence.offset
              line = @line_starts.bsearch_index { |start| start > offset } || @line_starts.size
              from = [@line_starts[[line - 2, 0].max], offset - ANCHOR_WINDOW].max

              pos = offset - 1
              while pos >= from
                byte = @input.getbyte(pos)
                if byte == 0x5b && pos > from && @input.getbyte(pos - 1) == 0x21 # `![`
                  # The image's `!` outranks its `[`: the `[` alone also
                  # matches, as a link, and being nearer would otherwise capture
                  # `[alt](…)` out of `![alt](…)`.
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

              # Linkify can take trailing bytes into the href that no URL
              # grammar accepts, so leaving exactly those bytes literal is
              # correct — core re-linkifies the whole thing after resolution.
              # `allow_prefix` bounds what may stay uncovered
              # ({Constructs::Base.swallowed_tail?}).
              construct_match_at(offset, occurrence, allow_prefix: true)
            end

            # A confirmed occurrence that is its own whole construct: a bare
            # schemeless domain (linkify links it, but no construct grammar has
            # a byte to trigger on) or a reference definition's destination. The
            # engine's href carries the scheme the route parses from; the span
            # replaced is exactly the raw spelling. The confirmation already
            # answered "is this really a link here?", so only the linkify
            # opening boundary is re-checked, mirroring what core requires ahead
            # of a bare URL.
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

            private

            def build_line_index
              @line_starts = [0]
              offset = 0
              while (offset = @input.byteindex("\n", offset))
                offset += 1
                @line_starts << offset
              end
            end

            def folded
              @folded ||= FoldedText.new(@input)
            end

            # Nil when the hit denotes no raw span: one starting or ending
            # inside a grapheme cluster names no raw bytes, and the round trip
            # re-folds the raw slice so a mapping that does not reproduce the
            # value is dropped rather than trusted. Both only ever lower the
            # count, so they escalate.
            def raw_span_of(offset, length, value)
              span = folded.raw_span(offset, length)
              return nil if span.nil?
              return nil unless FoldedText.fold(@input.byteslice(span[0], span[1])) == value

              span
            end

            def construct_for(kind)
              case kind
              when :mention
                @scanner.mention_construct
              when :hashtag
                @scanner.hashtag_construct
              when :emoji
                @scanner.emoji_construct
              end
            end

            def url_readings_for(value)
              @url_readings[value] ||= url_readings(value)
            end

            def collect_url_spans(reading, range, spans)
              length = reading.bytesize
              return if length == 0

              pos = range.begin
              limit = range.end - length
              while pos <= limit && (index = @input.byteindex(reading, pos))
                break if index > limit

                spans << Occurrence.new(offset: index, length:)
                pos = index + 1
              end
            end

            # Readings of one value can nest — the schemeless reading of a
            # scheme-ful spelling sits inside it, a decoded one inside its
            # encoded spelling — and a single raw occurrence must count once.
            # Two distinct links cannot share bytes, so overlapping spans are
            # always readings of one occurrence and the outermost is the span
            # the constructs anchor from.
            def coalesce(spans)
              kept = []
              spans.each do |span|
                last = kept.last
                next if last && span.offset < last.offset + last.length

                kept << span
              end
              kept
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
            # space, which is form encoding. Decoding runs on the bytes: a value
            # mixing non-ASCII characters with `%xx` would otherwise raise on
            # substituting a binary escape into a UTF-8 string.
            def percent_decode(value)
              return value unless value.include?("%")

              decoded =
                value
                  .b
                  .gsub(/%\h\h/) { |encoded| [encoded[1, 2]].pack("H2") }
                  .force_encoding(Encoding::UTF_8)
              decoded.valid_encoding? ? decoded : nil
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

            # See {Constructs::Base.swallowed_tail?}.
            def swallowed_tail?(from, to)
              Constructs::Base.swallowed_tail?(@input.byteslice(from, to - from))
            end
          end
        end
      end
    end
  end
end
