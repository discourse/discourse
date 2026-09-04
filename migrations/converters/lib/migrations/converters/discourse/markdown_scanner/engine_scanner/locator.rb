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

            # One spelling of a URL value. `schemeless` marks a reading the
            # scheme was stripped from, which is the only kind linkify can turn
            # back into a link on its own. `pattern` is set where the raw may
            # spell the reading with fewer escapes than the engine's href
            # ({#url_pattern}); it subsumes the plain scan for that text.
            Reading = Data.define(:text, :schemeless, :pattern)
            private_constant :Reading

            # The characters markdown-it's destination normalization leaves
            # alone; every other one it percent-escapes.
            URL_SAFE = %r{[A-Za-z0-9;/?:@&=+$,\-_.!~*'()#]}
            private_constant :URL_SAFE

            EMPTY_OCCURRENCES = [].freeze
            private_constant :EMPTY_OCCURRENCES

            EMPTY_VALUES = Set.new.freeze
            private_constant :EMPTY_VALUES

            # How far back a link's `[`/`!` anchor is searched from its
            # destination. Far above any real label, AI captions of a few
            # thousand bytes included; it only bounds the walk on bodies with
            # no anchor to find.
            ANCHOR_WINDOW = 16_384
            private_constant :ANCHOR_WINDOW

            def initialize(scanner, input)
              @scanner = scanner
              @input = input
              @occurrences = {}
              @url_spans = {}
              @raw_url_spans = {}
              @url_readings = {}
              @pattern_spans = {}
              @tracked_url_values = nil
              @unfiltered_url_values = EMPTY_VALUES
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
            # Hits that sit inside another tracked value's occurrence are then
            # dropped ({#reject_nested}).
            #
            # Memoized per (value, range), and bounded by
            # `EngineScanner::MAX_SCANNED_VALUES`.
            #
            # @return [Array<Occurrence>] sorted by offset
            def url_spans(value, range)
              @url_spans[[value, range]] ||= reject_nested(value, raw_url_spans(value, range))
            end

            # The tracked URL values of the body, so a hit can be recognized as
            # part of another value's occurrence (see {#reject_nested}).
            # `unfiltered` names the values that keep every hit.
            def track_url_values(values, unfiltered:)
              @tracked_url_values = values
              @unfiltered_url_values = unfiltered
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
                  text = reading.text
                  pattern =
                    /^ {0,3}\[[^\]\n]*\]:[^\S\n]*<?(?<dest>#{Regexp.escape(text)})>?(?=\s|\z)/
                  pos = 0
                  while (match = pattern.match(@input, pos))
                    offsets << [match.byteoffset(:dest).first, text.bytesize]
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

            # Try, nearest first, every possible syntax anchor within
            # `ANCHOR_WINDOW` bytes before the occurrence (a label may span
            # lines, so no line bound), then the occurrence itself as a bare
            # URL.
            def anchor_match(occurrence)
              offset = occurrence.offset
              from = [offset - ANCHOR_WINDOW, 0].max

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
              # ({Constructs::Base.swallowed_tail?}). Inside a destination's
              # parens there is no linkify tail to leave behind: the bytes the
              # grammar stopped at belong to the URL, so the whole occurrence
              # must be covered or nothing is.
              construct_match_at(
                offset,
                occurrence,
                allow_prefix: !link_destination_before?(@input, offset),
              )
            end

            # A confirmed occurrence that is its own whole construct: a bare
            # schemeless domain (linkify links it, but no construct grammar has
            # a byte to trigger on) or a reference definition's destination. The
            # engine's href carries the scheme the route parses from; the span
            # replaced is exactly the raw spelling.
            def bare_value_match(value, occurrence)
              raw_spelling = @input.byteslice(occurrence.offset, occurrence.length)
              node =
                definition_upload_node(value, occurrence, raw_spelling) ||
                  bare_link_node(value, occurrence, raw_spelling)
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

            # A definition whose destination is an upload defines the upload
            # itself, so the upload constructs answer for it: the `![alt][id]`
            # that uses the definition keeps its own syntax and only the
            # destination is replaced.
            def definition_upload_node(value, occurrence, raw_spelling)
              key = [occurrence.offset, occurrence.length]
              return nil unless definition_offsets(value).include?(key)

              @scanner.upload_node(raw_spelling)
            end

            # The confirmation already answered "is this really a link here?",
            # so only the linkify opening boundary is re-checked, mirroring what
            # core requires ahead of a bare URL.
            def bare_link_node(value, occurrence, raw_spelling)
              return nil unless linkify_boundary_before?(@input, occurrence.offset)

              @scanner.bare_url_node(route_url: value, url: raw_spelling)
            end

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

            # The union of the readings of one value in `range`, before the
            # cross-value pass. Memoized on its own, because that pass reads the
            # unfiltered spans of every tracked value.
            def raw_url_spans(value, range)
              @raw_url_spans[[value, range]] ||= begin
                spans = []
                url_readings_for(value).each { |reading| collect_url_spans(reading, range, spans) }
                spans.uniq!
                # Outermost first, so coalescing keeps the widest reading of a
                # nested pair.
                spans.sort_by! { |span| [span.offset, -span.length] }
                coalesce(spans).freeze
              end
            end

            def collect_url_spans(reading, range, spans)
              if reading.pattern
                pattern_spans(reading).each do |span|
                  if span.offset >= range.begin && span.offset + span.length <= range.end
                    spans << span
                  end
                end
                return
              end

              text = reading.text
              length = text.bytesize
              return if length == 0

              pos = range.begin
              limit = range.end - length
              while pos <= limit && (index = @input.byteindex(text, pos))
                break if index > limit

                spans << Occurrence.new(offset: index, length:) unless scheme_tail?(reading, index)
                pos = index + 1
              end
            end

            # A schemeless reading right after `//` is the tail of some scheme-ful
            # spelling: linkify starts no bare-domain link there, and a
            # destination or autolink written that way would carry its scheme,
            # so no live link can spell the value at this position.
            def scheme_tail?(reading, offset)
              reading.schemeless && offset >= 2 && @input.byteslice(offset - 2, 2) == "//"
            end

            # Hits of `value` that lie strictly inside a hit of another tracked
            # value are dropped: the enclosing bytes are one contiguous URL run,
            # so a live link there spells the longer value, and where the run is
            # shielded — a code span, a link label — both hits are shielded
            # alike. Values whose engine count includes a label hit keep every
            # hit, because there the shorter value is expected twice inside the
            # longer one's link.
            def reject_nested(value, spans)
              return spans if @tracked_url_values.nil? || @unfiltered_url_values.include?(value)

              offsets, ends = enclosing_spans
              return spans if offsets.empty?

              spans.reject { |span| enclosed?(offsets, ends, span) }.freeze
            end

            # Every tracked value's hits over the whole body, as start offsets
            # sorted ascending plus the running maximum of their end offsets, so
            # a containment test is two binary searches.
            def enclosing_spans
              @enclosing_spans ||=
                begin
                  whole = 0...@input.bytesize
                  all = @tracked_url_values.flat_map { |value| raw_url_spans(value, whole) }
                  all.uniq!
                  all.sort_by!(&:offset)
                  furthest = 0
                  ends = all.map { |span| furthest = [furthest, span.offset + span.length].max }
                  [all.map(&:offset).freeze, ends.freeze]
                end
            end

            def enclosed?(offsets, ends, span)
              finish = span.offset + span.length
              # A hit starting earlier encloses as soon as it reaches as far; one
              # starting here has to reach further, or it is the hit itself.
              before = last_index_below(offsets, span.offset)
              return true if before && ends[before] >= finish

              here = last_index_below(offsets, span.offset + 1)
              !here.nil? && ends[here] > finish
            end

            def last_index_below(offsets, limit)
              index = offsets.bsearch_index { |offset| offset >= limit }
              index = offsets.size if index.nil?
              index > 0 ? index - 1 : nil
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

            # Scanned over the whole body once, because a pattern cannot start
            # its search at a byte offset the way `byteindex` does.
            def pattern_spans(reading)
              @pattern_spans[reading.text] ||= begin
                spans = []
                pos = 0
                while (match = reading.pattern.match(@input, pos))
                  from, to = match.byteoffset(0)
                  unless scheme_tail?(reading, from)
                    spans << Occurrence.new(offset: from, length: to - from)
                  end
                  pos = match.begin(0) + 1
                end
                spans.freeze
              end
            end

            # A pattern that also accepts the raw spellings the engine's href
            # escaped on its way in: markdown-it escapes every unsafe character
            # of a destination and keeps the author's own `%xx` verbatim, so
            # each escape in the href may stand for either, independently.
            # `<…/search?q="%20%40name">` reaches the engine as
            # `…/search?q=%22%20%40name%22`. Nil unless the value has such an
            # escape.
            def url_pattern(text)
              parts = []
              mixed = false
              pos = 0

              while (match = /%\h\h(?:%\h\h)*/.match(text, pos))
                parts << Regexp.escape(text[pos...match.begin(0)])
                escapes = match[0]
                pos = match.end(0)

                decoded = percent_decode(escapes)
                if decoded.nil?
                  parts << Regexp.escape(escapes)
                  next
                end

                cursor = 0
                decoded.each_char do |char|
                  escaped = escapes[cursor, 3 * char.bytesize]
                  cursor += escaped.length
                  if char.match?(URL_SAFE)
                    parts << Regexp.escape(escaped)
                  else
                    mixed = true
                    parts << "(?:#{Regexp.escape(escaped)}|#{literal_branch(char)})"
                  end
                end
              end
              return nil unless mixed

              parts << Regexp.escape(text[pos..])
              Regexp.new(parts.join)
            end

            # A raw `%` only reaches the href as `%25` when it starts no escape
            # of its own; everything else stands for itself.
            def literal_branch(char)
              char == "%" ? "%(?!\\h\\h)" : Regexp.escape(char)
            end

            def url_readings(value)
              texts = [value]
              decoded = percent_decode(value)
              texts << decoded if decoded && decoded != value
              schemeful = texts.size

              bare = value.sub(%r{\Ahttps?://}i, "")
              if bare != value
                texts << bare
                bare_decoded = percent_decode(bare)
                texts << bare_decoded if bare_decoded && !texts.include?(bare_decoded)
              end

              texts.each_with_index.map do |text, index|
                Reading.new(text:, schemeless: index >= schemeful, pattern: url_pattern(text))
              end
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
