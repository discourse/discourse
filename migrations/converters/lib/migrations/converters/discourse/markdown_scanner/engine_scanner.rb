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
        # Certified occurrences are turned into nodes by the {Detectors},
        # anchored at the certified offsets — so the embeds recorded here have
        # exactly the shape the rest of the pipeline expects.
        class EngineScanner
          # `output` is the body with every proven construct replaced (equal to
          # the input when nothing was); `cause` names why at least one
          # construct stayed unproven with a stale reference (nil when
          # everything was placed); `detail` is the diagnostic a cause needs to
          # be actionable — today the exception class name behind an
          # `:engine_error` — and nil otherwise. `slow_parse` marks a body
          # whose parse only succeeded on the retry under the slow ceiling —
          # recovered, not refused, but worth tallying: those bodies will also
          # cook pathologically on the destination site.
          Result =
            Data.define(:output, :cause, :detail, :slow_parse) do
              def initialize(output:, cause:, detail: nil, slow_parse: false)
                super
              end

              def refused?
                !cause.nil?
              end
            end

          # A conversion runs once, so a body whose parse outruns the fast
          # ceiling gets one retry under this ceiling before `:engine_error`.
          # The fast ceiling still protects throughput for everything else.
          # Core's own PrettyText context allows 25 seconds for a full cook;
          # 30 seconds for a parse is far above any observed legitimate body
          # (slowest measured: 435 ms), and a corpus run at a 60-second
          # ceiling recovered zero additional bodies.
          SLOW_TIMEOUT_MS = 30_000

          # The most distinct tracked URL values one body may carry. Locating
          # URL occurrences scans per value, so a generated body with thousands
          # of distinct links costs value-count times body-size work in Ruby,
          # outside any V8 timeout. Past this count the body refuses with
          # `:url_volume` instead. Real posts stay far below it; a link index
          # this large is generated content.
          MAX_URL_VALUES = 256

          # One engine parse per body keeps the extraction flow simple. The
          # engine call amortizes ~30% better when several posts share one V8
          # round-trip; `MarkdownEngine::Context#scan` already takes a list, so
          # a posts step that wants that batches ahead of extraction instead of
          # this class growing look-ahead state.
          #
          # @param slow_timeout_ms [Integer, nil] the retry ceiling for a body
          #   whose parse the engine terminated; nil disables the retry and a
          #   terminated body refuses directly.
          def initialize(
            engine:,
            detectors:,
            gate:,
            internal_link_hosts: {},
            internal_link_base_prefix: nil,
            slow_timeout_ms: SLOW_TIMEOUT_MS,
            &on_node
          )
            @engine = engine
            @slow_timeout_ms = slow_timeout_ms
            @scan_timeout_ms = nil
            @gate = gate
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

            # The name-gated detectors, dispatched by trigger byte, for the
            # passes' one-walk occurrence index. Their triggers are disjoint
            # single bytes, so each byte maps to exactly one (kind, detector).
            @probe_dispatch = {}
            {
              mention: @mention_detector,
              hashtag: @hashtag_detector,
              emoji: @emoji_detector,
            }.each do |kind, detector|
              next if detector.nil?
              detector.triggers.each { |char| @probe_dispatch[char.ord] = [kind, detector].freeze }
            end
            @probe_dispatch.freeze
            @probe_stop =
              if @probe_dispatch.empty?
                nil
              else
                Regexp.new("[#{@probe_dispatch.keys.map { |byte| Regexp.escape(byte.chr) }.join}]")
              end
          end

          # @param input [String]
          # @return [Result]
          # @param scan_data [Hash, nil] a precomputed `MarkdownEngine::Context#scan`
          #   element for exactly this input's bytes. A batching caller amortizes
          #   the per-body V8 round-trip by scanning many bodies in one engine
          #   call and handing each result in here; trial substitution still
          #   parses live either way.
          def scan(input, scan_data: nil)
            @scan_timeout_ms = nil
            begin
              attempt(input, scan_data)
            rescue MiniRacer::ScriptTerminatedError, MiniRacer::RuntimeError
              raise if @slow_timeout_ms.nil?

              # One patient retry: a conversion runs once, so a minute spent
              # correctly remapping a pathological body beats leaving its
              # references stale. The whole body — trial parses included —
              # re-runs under the slow ceiling; a deterministic JS exception
              # will just fail again, which the single retry keeps cheap.
              @engine.reset!
              @scan_timeout_ms = @slow_timeout_ms
              attempt(input, scan_data).with(slow_parse: true)
            end
          rescue MiniRacer::ScriptTerminatedError, MiniRacer::RuntimeError => error
            # A per-input engine failure that survived the retry (or had none)
            # must cost that body, not the conversion: the body stays verbatim
            # on the tally and the context is rebuilt so the next body gets a
            # healthy engine. Process/resource failures are deliberately not
            # rescued.
            @engine.reset!
            Result.new(output: input, cause: :engine_error, detail: error.class.name)
          ensure
            @scan_timeout_ms = nil
          end

          # Every engine parse for the body in flight — the initial scan and
          # each trial — goes through here, so a body on the slow path carries
          # its ceiling into the trial parses too.
          def engine_scan(posts)
            @engine.scan(posts, timeout_ms: @scan_timeout_ms)
          end

          # One full extraction attempt; `scan` runs it fast first and once
          # more under the slow ceiling when the engine cut it off.
          def attempt(input, scan_data)
            data = scan_data || engine_scan([{ id: nil, raw: input }]).first

            # Count certification indexes the body by the engine's line maps,
            # which refer to lines after markdown-it normalized CR endings
            # away — a CR body goes straight to the map-free trial.
            cause = :cr_line_endings
            unless input.include?("\r")
              result = Pass.new(self, input, data).result
              return result unless result.refused?
              # Trials would pay the same per-value location cost the cap
              # exists to avoid, so an over-the-cap body refuses directly.
              return result if result.cause == :url_volume
              cause = result.cause
            end

            TrialPass.new(self, input, data, cause, seconds_budget: trial_seconds_budget).result
          end

          # On the slow path a single parse may legitimately take tens of
          # seconds, so the default trial budget would forbid even one trial
          # and make the retry pointless for a trial-eligible body — the
          # budget follows the ceiling instead (the trial count cap still
          # bounds the tail).
          def trial_seconds_budget
            return TrialPass::TRIAL_SECONDS_BUDGET if @scan_timeout_ms.nil?

            @scan_timeout_ms / 1000.0
          end

          # The pieces a {Pass} or {TrialPass} shares with its scanner.
          attr_reader :mention_detector,
                      :hashtag_detector,
                      :emoji_detector,
                      :quote_detector,
                      :url_dispatch,
                      :probe_dispatch,
                      :probe_stop,
                      :on_node

          # Tracking questions are answered by the detectors themselves — they
          # hold the name sets and the normalization, so the token filter here
          # and the grammar that later anchors a construct cannot drift apart.
          def mention_tracked?(name)
            !@mention_detector.nil? && @mention_detector.tracked_name?(name)
          end

          def emoji_tracked?(name)
            !@emoji_detector.nil? && @emoji_detector.tracked_name?(name)
          end

          # The certified text for an engine hashtag slug, nil when untracked.
          # Core's matcher admits trailing colons into the slug and its lookup
          # drops them (`"support:".split(":")`), while the detector grammar
          # keeps a dangling `:` outside the construct — so the certified text
          # must too. A `::type` suffix gates on the name alone.
          def hashtag_text(slug)
            ref = slug.sub(/:+\z/, "")
            return nil if ref.empty?

            name = ref.sub(/::(?:category|tag)\z/, "")
            return nil if @hashtag_detector.nil? || !@hashtag_detector.tracked_name?(name)

            "##{ref}"
          end

          def construct_capable_entity_offsets(text)
            @gate.construct_capable_entity_offsets(text)
          end

          # A link/image value the migration remaps: an `upload://` short URL,
          # a full URL with a supported upload shape (the detector's own
          # check, so an unrelated `/uploads/` path is not tracked), an
          # absolute URL on one of the source's own hosts (inside that host's
          # configured path prefix), or a site-relative path inside the base
          # prefix that parses as a route. External links are not constructs —
          # they can never refuse a body. The host/port/prefix reading is
          # {UrlOrigin}, the same one the detector grammar applies, so this
          # filter and the anchoring detectors cannot disagree about what is
          # internal.
          def url_tracked?(value)
            return true if value.start_with?("upload://")
            return true if Detectors::UploadUrl.tracked_value?(value)

            host, rest = UrlOrigin.split(value)
            return false if rest.nil?

            if host
              return !UrlOrigin.path_within_prefix(rest, @hosts[host]).nil? if @hosts.key?(host)

              # Untracked, but an internal-looking URL on an unconfigured host
              # is the forgotten-former-domain signal (once per host).
              @internal_link_detector&.note_foreign_url(value)
              return false
            end

            return false unless rest.start_with?("/")

            path = UrlOrigin.path_within_prefix(rest, @base_prefix)
            return false if path.nil?

            Detectors::InternalLink::RouteParser.parse(path) ? true : false
          end

          # The refusal cause for a tracked URL no grammar could place. A path
          # that steps into a coordinate route family but parses no route
          # (`/t//209`, `/u/bob!!!`) is a known class: the source data holds a
          # broken link, and rewriting only its origin would carry the stale
          # coordinates onto the new host. Everything else is `:unanchored` —
          # the engine proved a tracked occurrence and the detector grammar
          # has a real gap.
          def unplaced_url_cause(value)
            host, rest = UrlOrigin.split(value)
            path =
              if host
                @hosts.key?(host) ? UrlOrigin.path_within_prefix(rest, @hosts[host]) : nil
              elsif rest&.start_with?("/")
                UrlOrigin.path_within_prefix(rest, @base_prefix)
              end

            parser = Detectors::InternalLink::RouteParser
            if path && parser.coordinate_shaped?(path) && parser.parse(path).nil?
              :invalid_internal_route
            else
              :unanchored
            end
          end

          # A whole-construct reference for a proven URL occurrence that is its
          # own syntax — a bare schemeless domain linkify links, a reference
          # definition's destination. `route_url` is the engine's (normalized,
          # scheme-ful) href; `url` the raw spelling at the occurrence.
          def bare_url_node(route_url:, url:)
            @internal_link_detector&.reference_for(route_url:, url:)
          end

          # The per-body count-certification pass; the scanner itself stays
          # reusable across bodies.
          class Pass
            include Locating

            def initialize(scanner, input, data)
              @scanner = scanner
              @input = input
              @data = data
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

              # A body whose tracked constructs all turned out untracked or
              # placeholder-free needs no new string at all.
              Result.new(output: ordered.empty? ? @input : splice(ordered), cause: nil)
            end

            private

            def refusal(cause)
              Result.new(output: @input, cause:)
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
                  text = @scanner.hashtag_text(hashtag["slug"])
                  next if text.nil?
                  had = true
                  add_expected(:hashtag, text, range, 1)
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

              url_values = @expected.count { |(kind, _), _| kind == :url }
              return :url_volume if url_values > MAX_URL_VALUES

              # Entities decode before the engine's text rules run, so inside a
              # construct-bearing region a token value may not exist as literal
              # raw bytes — counting cannot see through that.
              regions_with_constructs.uniq.each { |range| return :entity if entity_in?(range) }

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
            #
            # A value with a reference-definition line takes its own rule
            # instead of the global count: one definition can serve several
            # `[text][label]` links, so the engine's token count may be larger
            # than the raw occurrence count. When every raw occurrence lies on
            # a definition line, replacing them rewrites all those links, and
            # certification accepts that. When occurrences sit elsewhere too, a
            # bare count equality could attribute a copy inside code to a
            # definition's reuse — so the value refuses and the trial pass
            # proves each occurrence on its own.
            def certify_all
              whole = 0...@input.bytesize
              @certified = {}

              @expected.each do |(kind, value), entry|
                occurrences = certify_regions(kind, value, entry)

                if occurrences
                  @certified[[kind, value]] = occurrences
                  next
                end

                return :entity if entity_offsets.any?

                if kind == :url && definition_offsets(value).any?
                  definitions = definition_only_spans(value, entry[:total])
                  return :reference_definition if definitions.nil?

                  @certified[[kind, value]] = definitions
                  next
                end

                global = certify_in(kind, value, whole, entry[:total])
                return :count_mismatch if global.nil?

                @certified[[kind, value]] = global
              end

              nil
            end

            # Every whole-body occurrence of the value, when each one lies on
            # a reference-definition line and the engine saw at least as many
            # tokens — nil otherwise.
            def definition_only_spans(value, expected)
              spans, overlapping = url_spans(value, 0...@input.bytesize)
              return nil if overlapping || spans.empty? || expected < spans.size

              definitions = definition_offsets(value)
              spans if spans.all? { |span| definitions.include?([span.offset, span.length]) }
            end

            # Every region certified, concatenated — nil when any region's
            # count is off.
            def certify_regions(kind, value, entry)
              occurrences = []
              entry[:regions].each do |range, expected|
                in_region = certify_in(kind, value, range, expected)
                return nil if in_region.nil?

                occurrences.concat(in_region)
              end
              occurrences
            end

            # The occurrences of a value in a range, when their number equals
            # what the engine saw — else nil.
            def certify_in(kind, value, range, expected)
              if kind == :url
                spans, overlapping = url_spans(value, range)
                return nil if overlapping
              else
                spans = occurrences_within(probed_occurrences(kind, value), range)
              end

              spans if spans.size == expected
            end

            # Turns certified URL occurrences into whole-construct detector
            # matches. A destination inside `[text](…)` must be replaced
            # together with its syntax; the detectors match from the `[`/`!`
            # anchor, which also naturally covers both occurrences of a
            # `[URL](same URL)` self-link with a single node. An occurrence
            # that is its own syntax (a bare schemeless domain, a reference
            # definition's destination) resolves through the engine's href
            # instead. One neither can take refuses the body: the trial pass
            # partial-extracts what it can, and the rest lands on the caller's
            # must-resolve tally rather than silently staying stale.
            def resolve_urls(spans)
              @certified.each do |(kind, value), occurrences|
                next unless kind == :url

                occurrences.each do |occurrence|
                  match = anchor_match(occurrence) || bare_value_match(value, occurrence)
                  return @scanner.unplaced_url_cause(value) if match.nil?
                  spans[[match.start_pos, match.end_pos]] ||= match
                end
              end

              nil
            end

            # Mentions, hashtags and emoji: their certified occurrences came
            # out of the detectors, so re-probing yields the node directly.
            def resolve_probed(spans)
              @certified.each do |(kind, _value), occurrences|
                next if kind == :url

                occurrences.each do |occurrence|
                  match = probe_match_at(kind, occurrence)
                  # The index was built from detector matches; a miss here
                  # means the pass is inconsistent with itself.
                  return :probe_desync if match.nil?
                  spans[[match.start_pos, match.end_pos]] ||= match
                end
              end

              nil
            end

            # Quote openers come from block tokens: the engine gives the
            # quote's line range directly, so no counting is needed — the
            # header on the opening line is parsed in place. This includes the
            # single-line `[quote=…]body[/quote]` form: block context is
            # certified by the engine, so no forward check is needed.
            def resolve_quotes(spans)
              @data["blockTokens"].each do |token|
                next unless token["type"] == "bbcode_open" && token["tag"] == "blockquote"

                range = region_range(token["map"])
                next if range.nil?

                line_end = @line_starts[token["map"][0] + 1] || @input.bytesize
                opener = @input.byteindex(/\[quote=/i, range.begin)
                next if opener.nil? || opener >= line_end

                # A header that parses but carries no username has nothing to
                # remap (core renders it without coordinates) and is skipped;
                # one the grammar could not take at all (beyond the pattern
                # caps, malformed) may hold remappable fields the pass failed
                # to reach, so it refuses instead of silently staying stale.
                match = @scanner.quote_detector.detect_block_opener(@input, opener)
                if match
                  spans[[match.start_pos, match.end_pos]] ||= match
                elsif !@scanner.quote_detector.parseable_opener?(@input, opener)
                  return :unanchored
                end
              end

              nil
            end
          end
        end
      end
    end
  end
end
