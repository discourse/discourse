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
          # ceiling deserves a patient second attempt before its references are
          # left stale: one retry under this ceiling, then `:engine_error`. The
          # fast ceiling still protects throughput for everything else.
          SLOW_TIMEOUT_MS = 60_000

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
            mention_names:,
            hashtag_names:,
            custom_emoji_names: nil,
            internal_link_hosts: {},
            internal_link_base_prefix: nil,
            slow_timeout_ms: SLOW_TIMEOUT_MS,
            &on_node
          )
            @engine = engine
            @slow_timeout_ms = slow_timeout_ms
            @scan_timeout_ms = nil
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
          # hosts (inside that host's configured path prefix), or a
          # site-relative path inside the base prefix that parses as a route.
          # External links are not constructs — they can never refuse a body.
          # The host/port/prefix reading is {UrlOrigin}, the same one the
          # detector grammar applies, so this filter and the anchoring
          # detectors cannot disagree about what is internal.
          def url_tracked?(value)
            return true if value.start_with?("upload://")
            return true if value.include?("/uploads/") || value.include?("/secure-uploads/")

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
                  # Core's matcher admits trailing colons into the slug and its
                  # Ruby-side lookup drops them (`"support:".split(":")`); the
                  # detector grammar keeps a dangling `:` outside the
                  # construct, so the certified text must too.
                  ref = hashtag["slug"].sub(/:+\z/, "")
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
            # what the engine saw — else nil. A URL value can be spelled in
            # alternate readings (the engine normalizes URLs: percent-encoding,
            # linkify adding a scheme to a bare-domain autolink), and the
            # readings must be counted as ONE union of spans, never
            # independently: with `` `http://host/t/5` `` in code and the
            # schemeless spelling in prose, the scheme-ful reading alone counts
            # 1 and would certify the code span — the union counts 2 against
            # the engine's 1 and refuses, so the trial pass can prove which
            # span is live.
            def certify(kind, value, range, expected)
              occurrences =
                if kind == :url
                  url_occurrence_union(value, range)
                else
                  occurrence_offsets(kind, value, range)
                end

              occurrences if occurrences && occurrences.size == expected
            end

            # Every reading's spans, deduplicated; nil when two distinct spans
            # overlap — no counting can attribute overlapping spellings, so
            # that ambiguity goes to the trial pass.
            def url_occurrence_union(value, range)
              spans = []
              url_readings(value).each do |reading|
                spans.concat(occurrence_offsets(:url, reading, range))
              end
              spans.uniq!
              spans.sort_by!(&:offset)
              spans.each_cons(2) do |left, right|
                return nil if right.offset < left.offset + left.length
              end
              spans
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
                  return :unanchored if match.nil?
                  spans[[match.start_pos, match.end_pos]] ||= match
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
