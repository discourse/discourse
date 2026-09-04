# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # Locates every construct the real discourse-markdown-it parse reported
        # in a post's raw bytes.
        #
        # The engine's token maps give the line range of each block. When a
        # value occurs in that range exactly as often as the engine created
        # tokens for it, every occurrence is live and all of them are replaced;
        # none can be inside a code span or a link label, because the engine
        # creates no tokens there. When a region's counts differ, the value is
        # counted once more against the whole post — the same exact equality,
        # without relying on the engine's line attribution. Why equality is
        # enough is argued once, in {MarkdownScanner}. Counts that cannot be
        # matched go to a {SubstitutionPass}.
        #
        # A confirmed name occurrence becomes a node from its own raw bytes; a
        # confirmed URL occurrence is anchored into the construct that surrounds
        # it (its `[`, its `!`, or the bare URL itself). Both go through the
        # {Constructs}, so the recorded embeds have the same shape as everywhere
        # else in the pipeline.
        class EngineScanner
          # `output` is the post with every confirmed construct replaced (the
          # input itself when nothing was). `cause` says why at least one
          # construct stayed unconfirmed; nil when everything was placed.
          # `detail` carries the exception class name for `:engine_error`.
          # `slow_parse` marks a post that only parsed on the slow retry —
          # recovered, not refused, but it will also cook very slowly on the
          # destination site.
          Result =
            Data.define(:output, :cause, :detail, :slow_parse) do
              def initialize(output:, cause:, detail: nil, slow_parse: false)
                super
              end
            end

          # A post whose parse runs into the fast ceiling gets one retry before
          # `:engine_error`. This is a deadline for the whole retry of that one
          # post, enforced per engine call in {#engine_scan}, not a fresh
          # ceiling per call. A conversion runs once, so 30 seconds on one post
          # is acceptable, and a corpus run with a 60-second ceiling recovered
          # no additional posts.
          SLOW_TIMEOUT_MS = 30_000

          # Raised when the retry deadline has passed, or when a call was cut
          # short by the shrinking deadline ceiling. The substitution pass turns
          # it into `:substitution_budget`; it never means the engine failed.
          class RetryDeadlineError < StandardError
          end

          # Locating occurrences scans the post once per distinct value, so a
          # generated post with thousands of them would spend one Ruby scan per
          # value, and none of that time sits inside V8's timeout. Above this
          # many of either kind the post refuses with `:url_volume` or
          # `:name_volume`.
          MAX_SCANNED_VALUES = 256

          # @param slow_timeout_ms [Integer, nil] the retry ceiling for a body
          #   whose parse the engine terminated; nil disables the retry.
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

            # Without one of these the scanner would silently drop every
            # construct of that kind, so all but the emoji one are required. A
            # source with no custom emoji leaves that one out on purpose.
            @mention_construct = required(constructs, Constructs::Mention)
            @hashtag_construct = required(constructs, Constructs::Hashtag)
            @quote_construct = required(constructs, Constructs::Quote)
            @internal_link_construct = required(constructs, Constructs::InternalLink)
            @emoji_construct = constructs.find { |construct| construct.is_a?(Constructs::Emoji) }

            # URL constructs are matched from their syntax anchor: `[`, `!`, or
            # the first byte of a bare URL.
            @url_dispatch = {}
            constructs.each do |construct|
              case construct
              when Constructs::Upload, Constructs::UploadUrl, Constructs::InternalLink
                construct.triggers.each { |char| (@url_dispatch[char.ord] ||= []) << construct }
              end
            end
            @url_dispatch.each_value(&:freeze)
            @url_dispatch.freeze
          end

          # @param input [String]
          # @param scan_data [Hash, nil] a precomputed
          #   `MarkdownEngine::Context#scan` element for exactly this input's
          #   bytes, as a batching caller supplies. Marker substitution parses
          #   live either way.
          # @return [Result]
          def scan(input, scan_data: nil)
            @scan_timeout_ms = nil
            @retry_deadline = nil
            begin
              attempt(input, scan_data)
            rescue MiniRacer::ScriptTerminatedError, MiniRacer::RuntimeError
              raise if @slow_timeout_ms.nil?

              # A deterministic JS exception fails again quickly, so the single
              # retry stays cheap.
              @engine.reset!
              @scan_timeout_ms = @slow_timeout_ms
              @retry_deadline =
                Process.clock_gettime(Process::CLOCK_MONOTONIC) + @slow_timeout_ms / 1000.0
              attempt(input, scan_data).with(slow_parse: true)
            end
          rescue MiniRacer::ScriptTerminatedError, MiniRacer::RuntimeError => error
            # An engine failure that survived the retry costs this body only;
            # the context is rebuilt so the next body gets a working engine.
            # Process and resource failures are not rescued.
            @engine.reset!
            Result.new(output: input, cause: :engine_error, detail: error.class.name)
          rescue RetryDeadlineError
            # The substitution pass turns the deadline into its budget cause
            # itself; this only catches one that passed outside it.
            Result.new(output: input, cause: :substitution_budget)
          ensure
            @scan_timeout_ms = nil
            @retry_deadline = nil
          end

          # Every engine parse for the current body goes through here. On the
          # slow retry each call gets only the time left until the per-body
          # deadline; without that, a substitution starting with one second left
          # could still run for the full ceiling.
          def engine_scan(posts)
            timeout = @scan_timeout_ms
            if @retry_deadline
              remaining_ms =
                ((@retry_deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)) * 1000).floor
              # Declining a call with no time left keeps the scan ceiling from
              # extending past the deadline.
              raise RetryDeadlineError if remaining_ms <= 0

              timeout = timeout.nil? ? remaining_ms : [timeout, remaining_ms].min
            end
            @engine.scan(posts, timeout_ms: timeout)
          end

          # The substitution pass classifies a terminated parse as spent budget
          # while the per-body deadline is in force, not as an engine failure.
          def retry_deadline_active?
            !@retry_deadline.nil?
          end

          # A terminated isolate cannot be reused; the pass that swallowed the
          # termination asks for the rebuild here.
          def reset_engine!
            @engine.reset!
          end

          attr_reader :mention_construct,
                      :hashtag_construct,
                      :emoji_construct,
                      :quote_construct,
                      :url_dispatch,
                      :on_node

          # The token filters below ask the constructs, so a filter and the node
          # built for a confirmed occurrence share one name set and one folding.
          def mention_tracked?(name)
            @mention_construct.tracked_name?(name)
          end

          def emoji_tracked?(name)
            !@emoji_construct.nil? && @emoji_construct.tracked_name?(name)
          end

          # The text to match for an engine hashtag slug; nil when the name is
          # not tracked. Core's matcher lets trailing colons into the slug and
          # its lookup drops them, so the raw text to look for drops them too. A
          # `::type` suffix takes no part in the name check.
          def hashtag_text(slug)
            ref = slug.sub(/:+\z/, "")
            return nil if ref.empty?

            name = ref.sub(/::(?:category|tag)\z/, "")
            return nil unless @hashtag_construct.tracked_name?(name)

            "##{ref}"
          end

          # A link or image value the migration remaps: an `upload://` short
          # URL, a full URL with a supported upload shape (the construct's own
          # check, so an unrelated `/uploads/` path is not tracked), an absolute
          # URL on one of the source's own hosts inside that host's prefix, or a
          # site-relative path inside the base prefix that parses as a route.
          # External links are not constructs and can never refuse a body. The
          # host and prefix reading is {UrlOrigin}, the same one the construct
          # grammar uses.
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

          # A path that starts a coordinate route family but parses no route
          # (`/t//209`, `/u/bob!!!`) is a broken link in the source data;
          # rewriting only its origin would carry the stale coordinates onto the
          # new host. Everything else is `:unanchored` — a real gap in the
          # construct grammar.
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

          # For a confirmed URL occurrence that is its own syntax (a bare
          # schemeless domain, a reference definition's destination).
          # `route_url` is the engine's normalized href; `url` is the raw
          # spelling at the occurrence.
          def bare_url_node(route_url:, url:)
            @internal_link_construct.reference_for(route_url:, url:)
          end

          private

          def attempt(input, scan_data)
            data = scan_data || engine_scan([{ id: nil, raw: input }]).first

            # One locator per body, shared by both passes: whatever the
            # count-matching pass built — the line index, the folded copy, the
            # occurrence lists — is exactly what the substitution pass needs
            # next.
            locator = Locator.new(self, input)

            # The engine's maps count lines after markdown-it normalized CR
            # endings away, so a CR body goes straight to the map-free
            # substitution pass.
            cause = :cr_line_endings
            unless input.include?("\r")
              result = CountingPass.new(self, input, data, locator).result
              return result if result.cause.nil?
              # Substitution checks would pay the same per-value cost the cap
              # avoids.
              return result if result.cause == :url_volume || result.cause == :name_volume
              cause = result.cause
            end

            SubstitutionPass.new(
              self,
              input,
              data,
              locator,
              cause,
              seconds_budget: substitution_seconds_budget,
            ).result
          end

          # On the slow path one parse may take tens of seconds, so the
          # substitution checks get what the slow parse left of the per-body
          # deadline — not a fresh {SLOW_TIMEOUT_MS} on top.
          def substitution_seconds_budget
            return SubstitutionPass::SUBSTITUTION_SECONDS_BUDGET if @retry_deadline.nil?

            remaining = @retry_deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
            remaining > 0 ? remaining : 0.0
          end

          def required(constructs, klass)
            construct = constructs.find { |candidate| candidate.is_a?(klass) }
            return construct if construct

            raise ArgumentError, "the engine scanner needs a #{klass} construct"
          end
        end
      end
    end
  end
end
