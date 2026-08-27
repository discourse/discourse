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
        # definitions live outside every block map).
        #
        # A body the counting cannot certify — ambiguous duplicate values, a
        # construct-capable character entity, CR line endings — escalates to a
        # {TrialPass}, which proves occurrences one by one through marker
        # substitution and re-parsing. Whatever even that cannot prove stays
        # verbatim, and the body is reported with its cause: certification and
        # trial can leave references stale, but they cannot corrupt.
        #
        # Certified occurrences are turned into nodes by the same detectors the
        # other scanners run, anchored at the certified offsets — so the embeds
        # recorded here have exactly the shape the rest of the pipeline
        # expects.
        class EngineScanner
          # `output` is the body with every proven construct replaced (equal to
          # the input when nothing was); `cause` names why at least one
          # construct stayed unproven (nil when everything was placed);
          # `unanchored` counts proven link occurrences no detector grammar
          # could turn into a node; `unproven` counts construct instances that
          # remain verbatim with stale references.
          Result =
            Data.define(:output, :cause, :unanchored, :unproven) do
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
            @internal_link_detector =
              detectors.find { |detector| detector.is_a?(Detectors::InternalLink) }

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
            data = @engine.scan([{ id: nil, raw: input }]).first

            # Count certification indexes the body by the engine's line maps,
            # which refer to lines after markdown-it normalized CR endings
            # away — a CR body goes straight to the map-free trial.
            cause = :cr_line_endings
            unless input.include?("\r")
              result = Pass.new(self, input, data).result
              return result unless result.refused?
              cause = result.cause
            end

            TrialPass.new(self, input, data, cause).result
          end

          # The pieces a {Pass} or {TrialPass} shares with its scanner.
          attr_reader :engine,
                      :mention_detector,
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
              return true if @hosts.key?(host)

              # Untracked, but an internal-looking URL on an unconfigured host
              # is the forgotten-former-domain signal (once per host).
              @internal_link_detector&.note_foreign_url(value)
              return false
            end

            return false unless value.start_with?("/")

            path = value
            path = path.delete_prefix(@base_prefix) if @base_prefix &&
              path.start_with?(@base_prefix)
            Detectors::InternalLink::RouteParser.parse(path) ? true : false
          end

          # The per-body count-certification pass; the scanner itself stays
          # reusable across bodies like the other scanners.
          class Pass
            include Locating

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

              Result.new(output: splice(ordered), cause: nil, unanchored: @unanchored, unproven: 0)
            end

            private

            def refusal(cause)
              Result.new(output: @input, cause:, unanchored: @unanchored, unproven: 0)
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
                # Not every inline block carries a line map (table cells don't);
                # a mapless block's constructs are counted against the whole
                # body — the same certification the global fallback applies,
                # with the entity precondition widening accordingly.
                range = region_range(block["map"]) || (0...@input.bytesize)

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

            def reference_definition?(value)
              url_readings(value).any? do |reading|
                @input.match?(/^ {0,3}\[[^\]\n]*\]:[^\S\n]*<?#{Regexp.escape(reading)}>?(?:\s|\z)/)
              end
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
            # walks cannot take: block context is certified by the engine,
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
          end
        end
      end
    end
  end
end
