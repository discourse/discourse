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
        # link label, because the engine creates no tokens there. When a
        # region's counts differ, the value is counted once more against the
        # whole post — the same exact equality, just without relying on the
        # engine's line attribution.
        #
        # When the counts cannot be matched (duplicate values in mixed
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
            end

          # A post whose parse runs into the fast ceiling gets one retry
          # before `:engine_error`. This is a deadline for the whole retry of
          # that one post, enforced per engine call in {#engine_scan}, not a
          # fresh ceiling per call. A conversion runs once, so spending up to
          # 30 seconds on one post is acceptable. Core's PrettyText allows
          # 25 seconds for a full cook; the slowest legitimate parse we
          # measured took 435 ms, and a corpus run with a 60-second ceiling
          # recovered no additional posts.
          SLOW_TIMEOUT_MS = 30_000

          # Raised in place of an engine call when the retry deadline has
          # passed, and in place of its result when the call was cut short by
          # the shrinking deadline ceiling. The substitution pass turns it
          # into `:substitution_budget`; it never means the engine failed.
          class RetryDeadlineError < StandardError
          end

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
            internal_link_hosts: {},
            internal_link_base_prefix: nil,
            slow_timeout_ms: SLOW_TIMEOUT_MS,
            &on_node
          )
            @engine = engine
            @slow_timeout_ms = slow_timeout_ms
            @scan_timeout_ms = nil
            @retry_deadline = nil
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
              Regexp.new("[#{@probe_dispatch.keys.map { |byte| Regexp.escape(byte.chr) }.join}]")
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
            @retry_deadline = nil
            begin
              attempt(input, scan_data)
            rescue MiniRacer::ScriptTerminatedError, MiniRacer::RuntimeError
              raise if @slow_timeout_ms.nil?

              # One retry with the slow ceiling. The whole attempt re-runs,
              # substitution parses included. A deterministic JS exception fails
              # again quickly, so the single retry stays cheap.
              @engine.reset!
              @scan_timeout_ms = @slow_timeout_ms
              @retry_deadline =
                Process.clock_gettime(Process::CLOCK_MONOTONIC) + @slow_timeout_ms / 1000.0
              attempt(input, scan_data).with(slow_parse: true)
            end
          rescue MiniRacer::ScriptTerminatedError, MiniRacer::RuntimeError => error
            # An engine failure that survived the retry costs this body only:
            # it stays unchanged and is reported, and the context is rebuilt
            # so the next body gets a working engine. Process and resource
            # failures are not rescued.
            @engine.reset!
            Result.new(output: input, cause: :engine_error, detail: error.class.name)
          rescue RetryDeadlineError
            # The substitution pass turns the deadline into its budget cause
            # itself; this only catches a deadline that passed outside it.
            Result.new(output: input, cause: :substitution_budget)
          ensure
            @scan_timeout_ms = nil
            @retry_deadline = nil
          end

          # Every engine parse for the current body goes through here. On the
          # slow retry each call gets only the time left until the per-body
          # deadline — without that, a substitution starting with one second
          # left could still run for the full ceiling — and a call with no
          # time left is not made.
          def engine_scan(posts)
            timeout = @scan_timeout_ms
            if @retry_deadline
              remaining_ms =
                ((@retry_deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)) * 1000).floor
              # A call with no time left is declined, so the scan ceiling can
              # never extend past the deadline; the isolate rebuild the
              # changed ceiling causes is the one piece of work outside the
              # engine's timeout, and only a pathological body — none in a
              # 1.5M-post corpus — pays for those rebuilds at all.
              raise RetryDeadlineError if remaining_ms <= 0

              timeout = timeout.nil? ? remaining_ms : [timeout, remaining_ms].min
            end
            @engine.scan(posts, timeout_ms: timeout)
          end

          # Whether the current body is on its slow retry, with the per-body
          # deadline in force. The substitution pass classifies a terminated
          # parse as spent budget then, not as an engine failure.
          def retry_deadline_active?
            !@retry_deadline.nil?
          end

          # A terminated isolate cannot be reused; the pass that swallowed the
          # termination asks for the rebuild here.
          def reset_engine!
            @engine.reset!
          end

          def attempt(input, scan_data)
            data = scan_data || engine_scan([{ id: nil, raw: input }]).first

            # The line index follows the engine's maps, and those count lines
            # after markdown-it normalized CR endings away. A CR body goes
            # straight to the map-free substitution pass.
            cause = :cr_line_endings
            unless input.include?("\r")
              result = CountingPass.new(self, input, data).result
              return result if result.cause.nil?
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
          private :attempt

          # On the slow path a single parse may take tens of seconds, and the
          # default substitution budget would not allow even one check. The
          # slow ceiling is a deadline for the retry of the whole body, so the
          # substitution checks get what the slow parse left of it — not a
          # fresh 30 seconds on top. The substitution count cap still limits
          # the total.
          def substitution_seconds_budget
            return SubstitutionPass::SUBSTITUTION_SECONDS_BUDGET if @retry_deadline.nil?

            remaining = @retry_deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
            remaining > 0 ? remaining : 0.0
          end
          private :substitution_seconds_budget

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
            @mention_construct.tracked_name?(name)
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
            return nil unless @hashtag_construct.tracked_name?(name)

            "##{ref}"
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
              @internal_link_construct.note_foreign_url(value)
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
            @internal_link_construct.reference_for(route_url:, url:)
          end
        end
      end
    end
  end
end
