# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # Extracts references from posts whose markdown needs context to
        # interpret (code blocks, links, escaped characters). The real
        # discourse-markdown-it engine parses the post; this class then
        # locates every construct the engine reported in the raw bytes.
        #
        # The engine's inline tokens have no source offsets, so positions are
        # recovered by counting. Token maps give the line range of each block.
        # When a value occurs in that range exactly as often as the engine
        # created tokens for it, every occurrence is a real construct and all
        # of them are replaced. None of them can be inside a code span or a
        # link label, because the engine creates no tokens there. When the
        # counts differ, the value is counted once more against the whole
        # post, because reference-link definitions are outside of all block
        # maps.
        #
        # When counting cannot match a post's occurrence counts (duplicate values in mixed
        # contexts, a character entity that could form a construct, CR line
        # endings), a {SubstitutionPass} confirms the occurrences one by one: it
        # replaces one occurrence with a marker, parses again, and checks the
        # difference. What even that cannot confirm stays unchanged, and the
        # post is reported with a cause. This can refuse a post, but it can
        # never corrupt one.
        #
        # Matched occurrences are turned into nodes by the {Constructs},
        # anchored at the matched offsets, so the recorded embeds have the
        # same shape as everywhere else in the pipeline.
        class EngineScanner
          # `output` is the post with every confirmed construct replaced; it is
          # the input itself when nothing was replaced. `cause` says why at
          # least one construct stayed unconfirmed; nil when everything was
          # placed. `detail` carries extra data for a cause, currently the
          # exception class name for `:engine_error`. `slow_parse` marks a
          # post that only parsed on the retry with the slow ceiling — it was
          # recovered, not refused, but such a post will also cook very slowly
          # on the destination site.
          Result =
            Data.define(:output, :cause, :detail, :slow_parse) do
              def initialize(output:, cause:, detail: nil, slow_parse: false)
                super
              end

              def refused?
                !cause.nil?
              end
            end

          # A post whose parse runs into the fast ceiling gets one retry with
          # this ceiling before `:engine_error`. A conversion runs once, so
          # spending up to 30 seconds on one post is acceptable. Core's
          # PrettyText allows 25 seconds for a full cook; the slowest
          # legitimate parse we measured took 435 ms, and a corpus run with a
          # 60-second ceiling recovered no additional posts.
          SLOW_TIMEOUT_MS = 30_000

          # Locating URL occurrences scans the post once per distinct value.
          # A generated post with thousands of distinct links would cost
          # value count times post size in Ruby, outside any V8 timeout.
          # Above this count the post refuses with `:url_volume`. Real posts
          # stay far below it.
          MAX_URL_VALUES = 256

          # @param slow_timeout_ms [Integer, nil] the retry ceiling for a body
          #   whose parse the engine terminated; nil disables the retry and a
          #   terminated body refuses directly.
          def initialize(
            engine:,
            constructs:,
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

            @mention_construct =
              constructs.find { |construct| construct.is_a?(Constructs::Mention) }
            @hashtag_construct =
              constructs.find { |construct| construct.is_a?(Constructs::Hashtag) }
            @emoji_construct = constructs.find { |construct| construct.is_a?(Constructs::Emoji) }
            @quote_construct = constructs.find { |construct| construct.is_a?(Constructs::Quote) }
            @internal_link_construct =
              constructs.find { |construct| construct.is_a?(Constructs::InternalLink) }

            # URL constructs are matched from their syntax anchor: `[`, `!`,
            # or the first byte of a bare URL.
            @url_dispatch = {}
            constructs.each do |construct|
              case construct
              when Constructs::Upload, Constructs::UploadUrl, Constructs::InternalLink
                construct.triggers.each { |char| (@url_dispatch[char.ord] ||= []) << construct }
              end
            end
            @url_dispatch.each_value(&:freeze)
            @url_dispatch.freeze

            # The name-gated constructs by trigger byte, for the one-walk
            # occurrence index. The trigger bytes are disjoint, so each byte
            # maps to exactly one (kind, construct) pair.
            @probe_dispatch = {}
            {
              mention: @mention_construct,
              hashtag: @hashtag_construct,
              emoji: @emoji_construct,
            }.each do |kind, construct|
              next if construct.nil?
              construct.triggers.each do |char|
                @probe_dispatch[char.ord] = [kind, construct].freeze
              end
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
          # @param scan_data [Hash, nil] a precomputed
          #   `MarkdownEngine::Context#scan` element for exactly this input's
          #   bytes. A batching caller scans many bodies in one engine call
          #   and passes each result in here; marker substitution parses live
          #   either way.
          # @return [Result]
          def scan(input, scan_data: nil)
            @scan_timeout_ms = nil
            begin
              attempt(input, scan_data)
            rescue MiniRacer::ScriptTerminatedError, MiniRacer::RuntimeError
              raise if @slow_timeout_ms.nil?

              # One retry with the slow ceiling. The whole attempt re-runs,
              # substitution parses included. A deterministic JS exception fails
              # again quickly, so the single retry stays cheap.
              @engine.reset!
              @scan_timeout_ms = @slow_timeout_ms
              attempt(input, scan_data).with(slow_parse: true)
            end
          rescue MiniRacer::ScriptTerminatedError, MiniRacer::RuntimeError => error
            # An engine failure that survived the retry costs this body only:
            # it stays unchanged and is reported, and the context is rebuilt
            # so the next body gets a working engine. Process and resource
            # failures are not rescued.
            @engine.reset!
            Result.new(output: input, cause: :engine_error, detail: error.class.name)
          ensure
            @scan_timeout_ms = nil
          end

          # Every engine parse for the current body goes through here, so a
          # body on the slow path keeps its ceiling for the substitution parses too.
          def engine_scan(posts)
            @engine.scan(posts, timeout_ms: @scan_timeout_ms)
          end

          def attempt(input, scan_data)
            data = scan_data || engine_scan([{ id: nil, raw: input }]).first

            # The line index follows the engine's maps, and those count lines
            # after markdown-it normalized CR endings away. A CR body goes
            # straight to the map-free substitution pass.
            cause = :cr_line_endings
            unless input.include?("\r")
              result = Pass.new(self, input, data).result
              return result unless result.refused?
              # Substitution checks would pay the same per-value cost the cap avoids.
              return result if result.cause == :url_volume
              cause = result.cause
            end

            SubstitutionPass.new(
              self,
              input,
              data,
              cause,
              seconds_budget: substitution_seconds_budget,
            ).result
          end

          # On the slow path a single parse may take tens of seconds. The
          # default substitution budget would not allow even one check, and the
          # retry would be pointless for such a body. So the budget
          # follows the ceiling; the substitution count cap still limits the total.
          def substitution_seconds_budget
            return SubstitutionPass::SUBSTITUTION_SECONDS_BUDGET if @scan_timeout_ms.nil?

            @scan_timeout_ms / 1000.0
          end

          attr_reader :mention_construct,
                      :hashtag_construct,
                      :emoji_construct,
                      :quote_construct,
                      :url_dispatch,
                      :probe_dispatch,
                      :probe_stop,
                      :on_node

          # The constructs hold the name sets and the normalization, so the
          # token filter here and the grammar that later anchors a construct
          # cannot drift apart.
          def mention_tracked?(name)
            !@mention_construct.nil? && @mention_construct.tracked_name?(name)
          end

          def emoji_tracked?(name)
            !@emoji_construct.nil? && @emoji_construct.tracked_name?(name)
          end

          # The text to match for an engine hashtag slug; nil when the name
          # is not tracked. Core's matcher lets trailing colons into the slug
          # and its lookup drops them, while the construct grammar keeps a
          # dangling `:` outside the construct — the matched text must do
          # the same. A `::type` suffix takes no part in the name check.
          def hashtag_text(slug)
            ref = slug.sub(/:+\z/, "")
            return nil if ref.empty?

            name = ref.sub(/::(?:category|tag)\z/, "")
            return nil if @hashtag_construct.nil? || !@hashtag_construct.tracked_name?(name)

            "##{ref}"
          end

          def construct_capable_entity_offsets(text)
            @gate.construct_capable_entity_offsets(text)
          end

          # A link or image value the migration remaps: an `upload://` short
          # URL, a full URL with a supported upload shape (the construct's own
          # check, so an unrelated `/uploads/` path is not tracked), an
          # absolute URL on one of the source's own hosts inside that host's
          # configured path prefix, or a site-relative path inside the base
          # prefix that parses as a route. External links are not constructs
          # and can never refuse a body. The host and prefix reading is
          # {UrlOrigin}, the same one the construct grammar uses, so this
          # filter and the anchoring constructs cannot disagree.
          def url_tracked?(value)
            return true if value.start_with?("upload://")
            return true if Constructs::UploadUrl.tracked_value?(value)

            host, rest = UrlOrigin.split(value)
            return false if rest.nil?

            if host
              return !UrlOrigin.path_within_prefix(rest, @hosts[host]).nil? if @hosts.key?(host)

              # An internal-looking URL on an unconfigured host may be a
              # forgotten former domain; report it once per host.
              @internal_link_construct&.note_foreign_url(value)
              return false
            end

            return false unless rest.start_with?("/")

            path = UrlOrigin.path_within_prefix(rest, @base_prefix)
            return false if path.nil?

            Constructs::InternalLink::RouteParser.parse(path) ? true : false
          end

          # The refusal cause for a tracked URL no grammar could place. A
          # path that starts a coordinate route family but parses no route
          # (`/t//209`, `/u/bob!!!`) is a broken link in the source data;
          # rewriting only its origin would carry the stale coordinates onto
          # the new host. Everything else is `:unanchored`: the engine recognized
          # a tracked occurrence and the construct grammar has a real gap.
          def unplaced_url_cause(value)
            host, rest = UrlOrigin.split(value)
            path =
              if host
                @hosts.key?(host) ? UrlOrigin.path_within_prefix(rest, @hosts[host]) : nil
              elsif rest&.start_with?("/")
                UrlOrigin.path_within_prefix(rest, @base_prefix)
              end

            parser = Constructs::InternalLink::RouteParser
            if path && parser.coordinate_shaped?(path) && parser.parse(path).nil?
              :invalid_internal_route
            else
              :unanchored
            end
          end

          # A whole-construct reference for a confirmed URL occurrence that is
          # its own syntax (a bare schemeless domain, a reference
          # definition's destination). `route_url` is the engine's normalized
          # href; `url` is the raw spelling at the occurrence.
          def bare_url_node(route_url:, url:)
            @internal_link_construct&.reference_for(route_url:, url:)
          end

          # The per-body count-matching pass; the scanner itself stays
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
              cause ||= match_all_counts
              cause ||= resolve_urls(spans)
              cause ||= resolve_probed(spans)
              cause ||= resolve_quotes(spans)
              return refusal(cause) if cause

              ordered = spans.values.sort_by(&:start_pos)
              return refusal(:overlap) if overlapping?(ordered)

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

            # Groups the engine's construct values: per (kind, value) the
            # expected count in each block region and in total. Values the
            # migration does not remap (external links, unknown names,
            # standard emoji) never enter count matching.
            def collect_expected
              @expected = {}
              regions_with_constructs = []

              @data["blocks"].each do |block|
                # Not every inline block has a line map; table cells do not.
                # A mapless block's constructs are counted against the whole
                # body, and the entity check widens accordingly.
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

              # Entities decode before the engine's text rules run, so a
              # token value may not exist as literal bytes in the raw text.
              # Counting cannot see through that.
              regions_with_constructs.uniq.each { |range| return :entity if entity_in?(range) }

              nil
            end

            def add_expected(kind, value, range, count)
              entry = @expected[[kind, value]] ||= { regions: Hash.new(0), total: 0 }
              entry[:regions][range] += count
              entry[:total] += count
            end

            # Two-stage count matching per value. A value matched inside its regions
            # replaces only those occurrences; the same value inside
            # a code fence elsewhere stays untouched. A value matched against the whole
            # body replaces every occurrence, and the entity check widens to
            # the whole body.
            #
            # A value with a reference-definition line has its own rule. One
            # definition can serve several `[text][label]` links, so the
            # engine may see more tokens than there are raw occurrences.
            # When every raw occurrence lies on a definition line, replacing
            # them rewrites all those links, and that counts as a match.
            # When some occurrences sit elsewhere, a plain count equality
            # could assign a copy inside code to the definition's reuse — so
            # the value refuses and the substitution pass confirms each occurrence on
            # its own.
            def match_all_counts
              whole = 0...@input.bytesize
              @matched = {}

              @expected.each do |(kind, value), entry|
                occurrences = match_region_counts(kind, value, entry)

                if occurrences
                  @matched[[kind, value]] = occurrences
                  next
                end

                return :entity if entity_offsets.any?

                if kind == :url && definition_offsets(value).any?
                  definitions = definition_only_spans(value, entry[:total])
                  return :reference_definition if definitions.nil?

                  @matched[[kind, value]] = definitions
                  next
                end

                global = match_counts_in(kind, value, whole, entry[:total])
                return :count_mismatch if global.nil?

                @matched[[kind, value]] = global
              end

              nil
            end

            # Every whole-body occurrence of the value, when each one lies on
            # a reference-definition line and the engine saw at least as many
            # tokens; nil otherwise.
            def definition_only_spans(value, expected)
              spans, overlapping = url_spans(value, 0...@input.bytesize)
              return nil if overlapping || spans.empty? || expected < spans.size

              definitions = definition_offsets(value)
              spans if spans.all? { |span| definitions.include?([span.offset, span.length]) }
            end

            # All regions matched and concatenated; nil when any region's
            # count does not match.
            def match_region_counts(kind, value, entry)
              occurrences = []
              entry[:regions].each do |range, expected|
                in_region = match_counts_in(kind, value, range, expected)
                return nil if in_region.nil?

                occurrences.concat(in_region)
              end
              occurrences
            end

            # The occurrences of a value in a range, when their number equals
            # what the engine saw; nil otherwise.
            def match_counts_in(kind, value, range, expected)
              if kind == :url
                spans, overlapping = url_spans(value, range)
                return nil if overlapping
              else
                spans = occurrences_within(probed_occurrences(kind, value), range)
              end

              spans if spans.size == expected
            end

            # Turns matched URL occurrences into node matches that cover the
            # whole construct. A destination inside `[text](…)` must be
            # replaced together with its syntax, so the classes match from the `[`
            # or `!` anchor; that also covers both occurrences of a
            # `[URL](same URL)` self-link with one node. An occurrence that
            # is its own syntax (a bare schemeless domain, a reference
            # definition's destination) resolves through the engine's href.
            # One that neither can take refuses the body; the substitution pass then
            # extracts what it can and the rest is reported.
            def resolve_urls(spans)
              @matched.each do |(kind, value), occurrences|
                next unless kind == :url

                occurrences.each do |occurrence|
                  match = anchor_match(occurrence) || bare_value_match(value, occurrence)
                  return @scanner.unplaced_url_cause(value) if match.nil?
                  spans[[match.start_pos, match.end_pos]] ||= match
                end
              end

              nil
            end

            # Mentions, hashtags and emoji: their matched occurrences came
            # from the constructs, so probing again returns the node directly.
            def resolve_probed(spans)
              @matched.each do |(kind, _value), occurrences|
                next if kind == :url

                occurrences.each do |occurrence|
                  match = probe_match_at(kind, occurrence)
                  # The index was built from construct matches; a miss here
                  # means the pass is inconsistent with itself.
                  return :probe_desync if match.nil?
                  spans[[match.start_pos, match.end_pos]] ||= match
                end
              end

              nil
            end

            # Quote openers come from block tokens: the engine reports the
            # quote's line range directly, so no counting is needed. The
            # header on the opening line is parsed in place. This includes
            # the single-line `[quote=…]body[/quote]` form.
            def resolve_quotes(spans)
              @data["blockTokens"].each do |token|
                next unless token["type"] == "bbcode_open" && token["tag"] == "blockquote"

                range = region_range(token["map"])
                next if range.nil?

                line_end = @line_starts[token["map"][0] + 1] || @input.bytesize
                opener = @input.byteindex(/\[quote=/i, range.begin)
                next if opener.nil? || opener >= line_end

                # A header that parses but has no username has nothing to
                # remap; core renders it without coordinates. A header the
                # grammar could not read at all may still hold remappable
                # fields, so it refuses instead of keeping stale data.
                match = @scanner.quote_construct.detect_block_opener(@input, opener)
                if match
                  spans[[match.start_pos, match.end_pos]] ||= match
                elsif !@scanner.quote_construct.parseable_opener?(@input, opener)
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
