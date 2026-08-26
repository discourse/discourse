# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # Extraction for bodies whose syntax makes context matter: the real
        # discourse-markdown-it engine parses the body, and every construct it
        # reports is located in the raw bytes by count certification.
        #
        # The engine's inline tokens carry no source offsets, so a construct's
        # position is recovered by counting: within a block's line range (token
        # maps are line-level), a value is only replaced when the number of raw
        # occurrences equals the number of tokens the engine produced — then
        # every occurrence is the real thing, and none of them sits inside code
        # or a link label the engine skipped. A value that fails its block
        # region gets one more chance against the whole body (reference-link
        # definitions live outside every block map). Anything still unequal
        # refuses the whole body: it stays verbatim and the caller records the
        # cause. Certification can refuse, but it cannot corrupt.
        #
        # Certified occurrences are turned into nodes by the same detectors the
        # other scanners run, anchored at the certified offsets — so the embeds
        # recorded here have exactly the shape the rest of the pipeline
        # expects.
        #
        # Preconditions, both fail-closed:
        # - CR line endings refuse outright: markdown-it normalizes them away
        #   before tokenizing, so its line maps would not match our line index.
        # - A construct-capable character entity in any construct-bearing
        #   region refuses: entities decode before the engine's text rules run,
        #   so a token's value no longer has to equal a literal raw substring.
        class EngineScanner
          # `output` is the body with certified constructs replaced (nil when
          # refused); `cause` names the refusal (nil on success); `unanchored`
          # counts certified link occurrences no detector grammar could turn
          # into a node — those stay verbatim without refusing the body, the
          # same way the line-oriented scanners leave unsupported link forms
          # alone.
          Result =
            Data.define(:output, :cause, :unanchored) do
              def refused?
                !cause.nil?
              end
            end

          # One engine parse per body keeps the extraction flow simple. The
          # engine call amortizes ~30% better when several posts share one V8
          # round-trip; `MarkdownEngine::Context#scan` already takes a list, so
          # a posts step that wants that batches ahead of extraction instead of
          # this class growing look-ahead state.
          def initialize(
            engine:,
            detectors:,
            gate:,
            mention_names:,
            hashtag_names:,
            custom_emoji_names: nil,
            internal_link_hosts: {},
            internal_link_base_prefix: nil,
            &on_node
          )
            @engine = engine
            @gate = gate
            @mention_names = mention_names
            @hashtag_names = hashtag_names
            @custom_emoji_names = (custom_emoji_names || []).to_set
            @hosts = internal_link_hosts
            @base_prefix = internal_link_base_prefix
            @on_node = on_node

            @mention_detector = detectors.find { |detector| detector.is_a?(Detectors::Mention) }
            @hashtag_detector = detectors.find { |detector| detector.is_a?(Detectors::Hashtag) }
            @emoji_detector = detectors.find { |detector| detector.is_a?(Detectors::Emoji) }
            @quote_detector = detectors.find { |detector| detector.is_a?(Detectors::Quote) }

            # URL-shaped constructs are matched from their syntax anchor (`[`,
            # `!`, or the URL itself for a bare link), so anchor resolution
            # dispatches by anchor byte like the scanners do.
            @url_dispatch = {}
            detectors.each do |detector|
              case detector
              when Detectors::Upload, Detectors::UploadUrl, Detectors::InternalLink
                detector.triggers.each { |char| (@url_dispatch[char.ord] ||= []) << detector }
              end
            end
            @url_dispatch.each_value(&:freeze)
            @url_dispatch.freeze
          end

          # @param input [String]
          # @return [Result]
          def scan(input)
            if input.include?("\r")
              return Result.new(output: nil, cause: :cr_line_endings, unanchored: 0)
            end

            data = @engine.scan([{ id: nil, raw: input }]).first
            Pass.new(self, input, data).result
          end

          # The pieces a {Pass} shares with its scanner.
          attr_reader :mention_detector,
                      :hashtag_detector,
                      :emoji_detector,
                      :quote_detector,
                      :url_dispatch,
                      :on_node

          def mention_tracked?(name)
            @mention_names.include?(Migrations::NameNormalizer.normalize(name))
          end

          def hashtag_tracked?(ref)
            name = ref.sub(/::(?:category|tag)\z/, "")
            @hashtag_names.include?(Migrations::NameNormalizer.normalize(name))
          end

          def emoji_tracked?(name)
            @custom_emoji_names.include?(name)
          end

          def entity_capable?(text)
            @gate.construct_capable_entity?(text)
          end

          # A link/image value the migration remaps: an `upload://` short URL,
          # a full upload URL, an absolute URL on one of the source's own
          # hosts, or a site-relative path that parses as a route. External
          # links are not constructs — they can never refuse a body.
          def url_tracked?(value)
            return true if value.start_with?("upload://")
            return true if value.include?("/uploads/") || value.include?("/secure-uploads/")

            if (match = %r{\A(?:https?:)?//(?<host>[^/?#]+)}i.match(value))
              host = match[:host].sub(/:(?:80|443)\z/, "").downcase
              return @hosts.key?(host)
            end

            return false unless value.start_with?("/")

            path = value
            path = path.delete_prefix(@base_prefix) if @base_prefix &&
              path.start_with?(@base_prefix)
            Detectors::InternalLink::RouteParser.parse(path) ? true : false
          end

          # The per-body state of one scan; the scanner itself stays reusable
          # across bodies like the other scanners.
          class Pass
            # A certified raw occurrence: where it starts and how many bytes
            # the certified reading spans there (an alternate URL reading can
            # differ in length from the engine's value).
            Occurrence = Data.define(:offset, :length)

            def initialize(scanner, input, data)
              @scanner = scanner
              @input = input
              @data = data
              @unanchored = 0
              build_line_index
            end

            def result
              spans = {}

              cause = collect_expected
              cause ||= certify_all
              cause ||= resolve_urls(spans)
              cause ||= resolve_probed(spans)
              cause ||= resolve_quotes(spans)
              return refusal(cause) if cause

              ordered = spans.values.sort_by(&:start_pos)
              return refusal(:overlap) if overlapping?(ordered)

              Result.new(output: splice(ordered), cause: nil, unanchored: @unanchored)
            end

            private

            def refusal(cause)
              Result.new(output: nil, cause:, unanchored: @unanchored)
            end

            def build_line_index
              @line_starts = [0]
              offset = 0
              while (offset = @input.byteindex("\n", offset))
                offset += 1
                @line_starts << offset
              end
            end

            def region_range(map)
              return nil if map.nil?

              from = @line_starts[map[0]]
              return nil if from.nil?

              to = @line_starts[map[1]] || @input.bytesize
              from...to
            end

            # Group the engine's construct values: per (kind, value) the
            # expected count in each block region plus the total. Values the
            # migration does not remap (external links, unknown mention names,
            # standard emoji) never enter certification — their occurrences
            # stay literal text either way.
            def collect_expected
              @expected = {}
              regions_with_constructs = []

              @data["blocks"].each do |block|
                range = region_range(block["map"])
                next if range.nil?

                had = false
                block["mentions"].each do |content|
                  next unless @scanner.mention_tracked?(content.delete_prefix("@"))
                  had = true
                  add_expected(:mention, content, range, 1)
                end
                block["hashtags"].each do |hashtag|
                  ref = hashtag["slug"]
                  next if ref.empty? || !@scanner.hashtag_tracked?(ref)
                  had = true
                  add_expected(:hashtag, "##{ref}", range, 1)
                end
                block["emojis"].each do |name|
                  next unless @scanner.emoji_tracked?(name)
                  had = true
                  add_expected(:emoji, ":#{name}:", range, 1)
                end
                block["links"].each do |link|
                  href = link["href"]
                  next unless @scanner.url_tracked?(href)
                  had = true
                  add_expected(:url, href, range, 1 + link["labelHits"])
                end
                block["images"].each do |src|
                  next unless @scanner.url_tracked?(src)
                  had = true
                  add_expected(:url, src, range, 1)
                end

                regions_with_constructs << range if had
              end

              # Entities decode before the engine's text rules run, so inside a
              # construct-bearing region a token value may not exist as literal
              # raw bytes — counting cannot see through that.
              regions_with_constructs.uniq.each do |range|
                return :entity if @scanner.entity_capable?(@input.byteslice(range))
              end

              nil
            end

            def add_expected(kind, value, range, count)
              entry = @expected[[kind, value]] ||= { regions: Hash.new(0), total: 0 }
              entry[:regions][range] += count
              entry[:total] += count
            end

            # Two-stage count certification per value. A region-certified value
            # replaces only its in-region occurrences (the same value inside a
            # code fence elsewhere stays put); a globally certified value
            # replaces every occurrence, at the price of the entity
            # precondition widening to the whole body.
            def certify_all
              whole = 0...@input.bytesize
              @certified = {}

              @expected.each do |(kind, value), entry|
                occurrences = []
                failed = false

                entry[:regions].each do |range, expected|
                  in_region = certify(kind, value, range, expected)
                  if in_region
                    occurrences.concat(in_region)
                  else
                    failed = true
                    break
                  end
                end

                unless failed
                  @certified[[kind, value]] = occurrences
                  next
                end

                return :entity if @scanner.entity_capable?(@input)

                global = certify(kind, value, whole, entry[:total])
                if global
                  @certified[[kind, value]] = global
                elsif kind == :url && reference_definition?(value)
                  # Real, but the destination lives on a definition line whose
                  # syntax no detector rewrites — refuse rather than guess.
                  return :reference_definition
                else
                  return :count_mismatch
                end
              end

              nil
            end

            # The occurrences of a value in a range, when their number equals
            # what the engine saw — else nil. A URL value is also tried in its
            # alternate readings (the engine normalizes URLs: percent-encoding,
            # linkify adding a scheme to a bare-domain autolink); the first
            # reading whose count matches is the one spliced.
            def certify(kind, value, range, expected)
              readings = kind == :url ? url_readings(value) : [value]

              readings.each do |reading|
                occurrences = occurrence_offsets(kind, reading, range)
                return occurrences if occurrences.size == expected
              end

              nil
            end

            def occurrence_offsets(kind, reading, range)
              occurrences = []
              length = reading.bytesize
              pos = range.begin
              limit = range.end - length

              while pos <= limit && (index = @input.byteindex(reading, pos))
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

            URL_BYTES = [*"a".."z", *"A".."Z", *"0".."9", "/"].to_set(&:ord).freeze
            TRAILING_PUNCTUATION = ".?#&=%~_-".bytes.to_set.freeze
            private_constant :URL_BYTES, :TRAILING_PUNCTUATION

            def reference_definition?(value)
              url_readings(value).any? do |reading|
                @input.match?(/^ {0,3}\[[^\]\n]*\]:[^\S\n]*<?#{Regexp.escape(reading)}>?(?:\s|\z)/)
              end
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

            # Turns certified URL occurrences into whole-construct detector
            # matches. A destination inside `[text](…)` must be replaced
            # together with its syntax; the detectors match from the `[`/`!`
            # anchor, which also naturally covers both occurrences of a
            # `[URL](same URL)` self-link with a single node. An occurrence no
            # detector grammar can take stays verbatim and is tallied instead
            # of refusing the body.
            def resolve_urls(spans)
              @certified.each do |(kind, _value), occurrences|
                next unless kind == :url

                occurrences.each do |occurrence|
                  match = anchor_match(occurrence)
                  if match.nil?
                    @unanchored += 1
                  else
                    spans[[match.start_pos, match.end_pos]] ||= match
                  end
                end
              end

              nil
            end

            # Try, nearest first, every possible syntax anchor between the
            # occurrence and the start of the previous line (a link's
            # destination may sit one line below its `[` — see
            # `Base::LINK_GAP`), then the occurrence itself as a bare URL.
            def anchor_match(occurrence)
              offset = occurrence.offset
              line = @line_starts.bsearch_index { |start| start > offset } || @line_starts.size
              from = @line_starts[[line - 2, 0].max]

              anchors = []
              pos = from
              while pos < offset
                byte = @input.getbyte(pos)
                anchors << pos if byte == 0x21 || byte == 0x5b # `!` `[`
                pos += 1
              end

              anchors.reverse_each do |anchor|
                match = detector_match_at(anchor, occurrence)
                return match if match
              end

              detector_match_at(offset, occurrence)
            end

            def detector_match_at(anchor, occurrence)
              byte = @input.getbyte(anchor)
              @scanner.url_dispatch[byte]&.each do |detector|
                match = detector.detect(@input, anchor, byte)
                next if match.nil?
                if match.start_pos <= occurrence.offset &&
                     match.end_pos >= occurrence.offset + occurrence.length
                  return match
                end
              end
              nil
            end

            # Mentions, hashtags and emoji: their certified occurrences came
            # out of the detectors, so re-probing yields the node directly.
            def resolve_probed(spans)
              @certified.each do |(kind, value), occurrences|
                next if kind == :url

                occurrences.each do |occurrence|
                  match = probe_match(kind, value, occurrence.offset)
                  # The probe validated this exact offset during counting; a
                  # miss here means the pass is inconsistent with itself.
                  return :probe_desync if match.nil?
                  spans[[match.start_pos, match.end_pos]] ||= match
                end
              end

              nil
            end

            # Quote openers come from block tokens: the engine gives the
            # quote's line range directly, so no counting is needed — the
            # header on the opening line is parsed in place. This includes the
            # single-line `[quote=…]body[/quote]` form the line-oriented
            # scanners cannot take: block context is certified by the engine,
            # so the forward spaces-only check does not apply.
            def resolve_quotes(spans)
              @data["blockTokens"].each do |token|
                next unless token["type"] == "bbcode_open" && token["tag"] == "blockquote"

                range = region_range(token["map"])
                next if range.nil?

                line_end = @line_starts[token["map"][0] + 1] || @input.bytesize
                opener = @input.byteindex(/\[quote=/i, range.begin)
                next if opener.nil? || opener >= line_end

                match = @scanner.quote_detector.detect_block_opener(@input, opener)
                # A header core renders without coordinates (`[quote="post:5"]`)
                # carries nothing to remap; leaving it is not a refusal.
                spans[[match.start_pos, match.end_pos]] ||= match if match
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
