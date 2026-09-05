# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      # Extracts deferred embeds from a Discourse post's Markdown `raw` and
      # replaces each with a placeholder token, recording a typed descriptor on
      # the embed collector given at construction (an {EmbedBuffer}). The
      # importer's `PlaceholderResolver` rewrites the tokens once the
      # `original_id -> discourse_id` maps exist.
      #
      # The hard part is *not* extracting from places that only look like embeds
      # — inside fenced/indented/inline code, or in a link's label or
      # destination. A {MarkdownScanner::TierGate} classifies every body first:
      # most have nothing extractable and pass through untouched, the rest go to
      # the {MarkdownScanner::EngineScanner} (see {MarkdownScanner}).
      #
      # Polls and events are self-contained (no id remapping needed), so they're
      # left in `raw` verbatim.
      class RawExtractor
        # A body normalized and classified once, ready for bounded batch
        # scanning and later extraction with the matching scan data.
        PreparedBody =
          Data.define(:id, :raw, :topic_id, :tier) do
            def engine_bound?
              tier == :engine
            end
          end

        # The measured throughput sweet spot is 32 ordinary posts per V8 call
        # (see {#scan_batches}). The byte cap keeps those calls from becoming
        # arbitrarily large; a single body over the cap still runs alone, so
        # valid large posts are not rejected for being unbatchable.
        DEFAULT_BATCH_POSTS = 32
        DEFAULT_BATCH_BYTES = 4 * 1024 * 1024

        Constructs = MarkdownScanner::Constructs
        private_constant :Constructs

        HashtagType = Migrations::Database::IntermediateDB::Enums::HashtagType
        private_constant :HashtagType

        LinkTarget = Migrations::Database::IntermediateDB::Enums::LinkTarget
        private_constant :LinkTarget

        # A hashtag node's forced type (from a `::category` / `::tag` suffix)
        # mapped to its stored enum value.
        FORCED_HASHTAG_TYPES = { category: HashtagType::CATEGORY, tag: HashtagType::TAG }.freeze
        private_constant :FORCED_HASHTAG_TYPES

        # A {Constructs::InternalLink} node's target kind mapped to the stored
        # `link_target` enum value.
        LINK_TARGET_TYPES = {
          topic: LinkTarget::TOPIC,
          post: LinkTarget::POST,
          user: LinkTarget::USER,
          category: LinkTarget::CATEGORY,
          tag: LinkTarget::TAG,
          group: LinkTarget::GROUP,
          badge: LinkTarget::BADGE,
          site: LinkTarget::SITE,
          category_tag: LinkTarget::CATEGORY_TAG,
          tag_intersection: LinkTarget::TAG_INTERSECTION,
        }.freeze
        private_constant :LINK_TARGET_TYPES

        # Only a mention, hashtag or custom emoji naming something the source
        # actually has is deferred; anything else stays literal text. That is
        # why the name sets are required: without them every `@word` that parses
        # would be rewritten, including the ones that name nobody. Names arrive
        # {NameNormalizer}-folded (custom emoji names are folded here), and with
        # no custom emoji names the emoji construct is left out entirely, so
        # posts don't pay for its `:` trigger.
        #
        # @param internal_link_hosts [Hash{String => (String, nil)}] the
        #   source's own hosts (base URL and former domains), each downcased and
        #   mapped to its path prefix — `"/forum"` for a subdirectory install
        #   (no trailing slash), `nil` for a root install. Hosts may carry
        #   different prefixes. Empty (the default) detects relative links only.
        # @param internal_link_base_prefix [String, nil] the current site's own
        #   path prefix, stripped from a relative link before the route is
        #   parsed.
        # @param on_foreign_host [#call, nil] called once per host with the host
        #   of an absolute, internal-looking link whose host is not in
        #   `internal_link_hosts` — a hint that a former domain may be missing
        #   from the source_site settings.
        # @param markdown_engine [MarkdownEngine::Context] the engine context
        #   for `:engine`-classified bodies. Build it after the worker forks —
        #   V8 contexts do not survive forking.
        # @param on_engine_refusal [#call, nil] called with the cause and its
        #   diagnostic detail (the exception class name for `:engine_error`,
        #   else nil) whenever an `:engine` body keeps at least one unconfirmed
        #   construct; also tallied on {#engine_refusals}. The caller knows
        #   which post it is extracting, so post identity stays on its side.
        # @param slow_timeout_ms [Integer, nil] the retry ceiling for a body
        #   whose parse the engine terminated at the fast default; `nil`
        #   disables it.
        # @param on_slow_parse [#call, nil] called with no arguments whenever a
        #   body's parse only succeeded on the slow retry; also counted on
        #   {#slow_parses}.
        def initialize(
          embeds:,
          mention_names:,
          hashtag_names:,
          markdown_engine:,
          mention_classifier: MentionClassifier.new,
          custom_emoji_names: nil,
          internal_link_hosts: {},
          internal_link_base_prefix: nil,
          on_foreign_host: nil,
          on_engine_refusal: nil,
          slow_timeout_ms: MarkdownScanner::EngineScanner::SLOW_TIMEOUT_MS,
          on_slow_parse: nil
        )
          @embeds = embeds
          @mention_classifier = mention_classifier
          @markdown_engine = markdown_engine
          @internal_link_hosts = internal_link_hosts
          @internal_link_base_prefix = internal_link_base_prefix
          @on_engine_refusal = on_engine_refusal
          @on_slow_parse = on_slow_parse
          @engine_refusals = Hash.new(0)
          @slow_parses = 0

          constructs = [Constructs::Upload.new, Constructs::UploadUrl.new, Constructs::Quote.new]
          # After UploadUrl, so an upload URL still wins over a bare internal
          # link that happens to look like one.
          constructs << Constructs::InternalLink.new(
            hosts: internal_link_hosts,
            base_prefix: internal_link_base_prefix,
            on_foreign_host:,
          )
          constructs << Constructs::Mention.new(names: mention_names)
          constructs << Constructs::Hashtag.new(names: hashtag_names)
          if custom_emoji_names.present?
            constructs << Constructs::Emoji.new(
              names:
                Migrations::CompactStringSet.new(
                  custom_emoji_names.map { |name| Migrations::NameNormalizer.normalize(name) },
                ),
            )
          end

          # The constructs carry no per-post state (the internal-link one only
          # accumulates its report-once host set) and the scanner resets its
          # state on each `scan`, so they are built once and reused. `extract`
          # swaps `@topic_id` per call, so one extractor must not run in two
          # threads at once — each worker holds its own.
          on_node = ->(node, source) { defer(node, source) }
          @gate = MarkdownScanner::TierGate.new(constructs:)
          @engine_scanner =
            MarkdownScanner::EngineScanner.new(
              engine: markdown_engine,
              constructs:,
              internal_link_hosts:,
              internal_link_base_prefix:,
              slow_timeout_ms:,
              &on_node
            )
        end

        # Cause tallies (`cause => count`) for `:engine` bodies that kept at
        # least one unconfirmed construct — the conversion's must-resolve list.
        # Only the first group should read as a problem with the extraction
        # itself:
        #
        #   * unexpected failure — `:unanchored` (the engine recognized a
        #     tracked occurrence, but no construct grammar could place it),
        #     `:engine_error`, `:overlap`;
        #   * known unsupported source content — `:invalid_internal_route` (a
        #     coordinate-shaped path that parses no route, usually a link
        #     already broken on the source), `:count_mismatch`, `:entity`,
        #     `:cr_line_endings`;
        #   * budget — `:substitution_limit`, `:substitution_budget`,
        #     `:url_volume`, `:name_volume`;
        #   * the rest of a partially extracted body.
        attr_reader :engine_refusals

        # How many bodies parsed only on the slow retry. They extracted fine, so
        # this is a heads-up count, not part of the must-resolve list.
        attr_reader :slow_parses

        # @param topic_id [Integer, nil] the containing post's source topic id,
        #   which completes a quote reference that names a `post:` but no
        #   `topic:` (Discourse omits `topic:` within one topic).
        # @return [String, nil] the body with embeds replaced by placeholder
        #   tokens. Invalid bytes are scrubbed and non-UTF-8 encodings converted
        #   here at the top, exactly once: the gate, the engine and every byte
        #   offset must all read the same bytes.
        def extract(raw, topic_id: nil)
          extract_prepared(prepare(raw:, topic_id:))
        end

        # A batching caller prepares each body once, passes the results to
        # {#scan_batches}, then calls {#extract_prepared} with the scan data
        # keyed by id.
        def prepare(raw:, id: nil, topic_id: nil)
          return PreparedBody.new(id:, raw:, topic_id:, tier: :none) if raw.nil?

          normalized = normalize_input(raw)
          PreparedBody.new(id:, raw: normalized, topic_id:, tier: @gate.classify(normalized))
        end

        # Partitions by both count and aggregate bytes. If one partition
        # terminates, only that partition returns no data; its bodies recover
        # through the per-body path in {#extract_prepared}.
        #
        # Batching exists because the per-call V8 overhead (~0.5ms) is
        # comparable to an average parse. On a 1.5M-post corpus at 18 workers,
        # batches of 32 measured 45.2s wall / 360.4s V8 against 70.9s / 684.4s
        # unbatched.
        def scan_batches(
          prepared_bodies,
          max_posts: DEFAULT_BATCH_POSTS,
          max_bytes: DEFAULT_BATCH_BYTES
        )
          validate_batch_limits!(max_posts, max_bytes)
          bodies = prepared_bodies.select(&:engine_bound?)
          ids = bodies.map(&:id)
          raise ArgumentError, "prepared bodies must have non-nil ids" if ids.any?(&:nil?)
          raise ArgumentError, "prepared bodies must have unique ids" if ids.uniq.size != ids.size

          data = {}
          each_scan_batch(bodies, max_posts:, max_bytes:) do |batch|
            data.merge!(scan_prepared_batch(batch))
          end
          data
        end

        def extract_prepared(prepared_body, scan_data: nil)
          @topic_id = prepared_body.topic_id
          return prepared_body.raw unless prepared_body.engine_bound?

          extract_engine(prepared_body.raw, scan_data)
        end

        private

        def validate_batch_limits!(max_posts, max_bytes)
          unless max_posts.is_a?(Integer) && max_posts.positive?
            raise ArgumentError, "max_posts must be a positive integer"
          end
          unless max_bytes.is_a?(Integer) && max_bytes.positive?
            raise ArgumentError, "max_bytes must be a positive integer"
          end
        end

        def each_scan_batch(bodies, max_posts:, max_bytes:)
          batch = []
          bytes = 0

          bodies.each do |body|
            body_bytes = body.raw.bytesize
            if batch.any? && (batch.size >= max_posts || bytes + body_bytes > max_bytes)
              yield batch
              batch = []
              bytes = 0
            end

            batch << body
            bytes += body_bytes
          end

          yield batch if batch.any?
        end

        def scan_prepared_batch(batch)
          posts = batch.map { |body| { id: body.id, raw: body.raw } }
          @markdown_engine.scan(posts).index_by { |data| data["id"] }
        rescue MiniRacer::ScriptTerminatedError, MiniRacer::RuntimeError
          @markdown_engine.reset!
          {}
        end

        def normalize_input(raw)
          if raw.encoding == Encoding::UTF_8
            raw.valid_encoding? ? raw : raw.scrub
          else
            raw.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
          end
        end

        # The cause is counted and reported so a conversion surfaces how many
        # posts (and why) still need resolution.
        def extract_engine(raw, scan_data)
          result = @engine_scanner.scan(raw, scan_data:)
          if result.slow_parse
            @slow_parses += 1
            @on_slow_parse&.call
          end
          if result.cause
            @engine_refusals[result.cause] += 1
            @on_engine_refusal&.call(result.cause, result.detail)
          end
          result.output
        end

        # Records the detected embed on the collector and returns the
        # placeholder token. `source` is the verbatim matched slice; it is
        # stored on every row so the importer can restore the exact source text
        # when the embed can't be mapped, instead of rebuilding a canonical
        # form.
        def defer(node, source)
          case node
          when Markbridge::AST::Upload
            @embeds.upload(upload_id: node.sha1, original_markdown: source)
          when MarkdownScanner::UploadUrlReference
            ownership = upload_ownership(node)
            # A relative path outside the base prefix belongs to another
            # application on the same server. There is no host to allowlist, so
            # it is not recorded at all and the source text stays.
            return nil if ownership == :sibling_path

            @embeds.upload(
              upload_id: node.sha1,
              original_markdown: source,
              external_host: ownership,
            )
          when Markbridge::AST::Mention
            @embeds.mention(
              mention_type: @mention_classifier.call(node.name),
              name: node.name,
              original_markdown: source,
            )
          when MarkdownScanner::InternalLinkReference
            @embeds.link(
              url: node.url,
              text: node.text,
              target_type: LINK_TARGET_TYPES.fetch(node.target_type),
              target_id: node.target_id,
              target_name: node.target_name,
              target_topic_id: node.target_topic_id,
              target_post_number: node.target_post_number,
              target_tag_path: node.target_tag_path,
              target_suffix: node.target_suffix,
              original_markdown: source,
              url_offset: node.url_offset,
              label_url_offset: node.label_url_offset,
            )
          when MarkdownScanner::HashtagReference
            @embeds.hashtag(
              hashtag_type: FORCED_HASHTAG_TYPES[node.forced_type],
              name: node.name,
              original_markdown: source,
            )
          when MarkdownScanner::EmojiReference
            @embeds.emoji(name: node.name)
          when MarkdownScanner::QuoteReference
            defer_quote(node, source)
          else
            raise NotImplementedError, "no defer handler for #{node.class}"
          end
        end

        # Whether a full-URL upload is the source's own. Returns nil when it is;
        # the host string when it is not (the importer then maps its sha1 only
        # against an explicit allowlist); `:sibling_path` for a relative URL
        # outside the base prefix. The prefix matters on a subdirectory install:
        # `https://example.com/other/uploads/…` shares the forum's host but
        # belongs to a different application.
        def upload_ownership(node)
          if node.host
            return node.host unless @internal_link_hosts.key?(node.host)

            prefix = @internal_link_hosts[node.host]
            MarkdownScanner::UrlOrigin.path_within_prefix(node.rest, prefix).nil? ? node.host : nil
          elsif MarkdownScanner::UrlOrigin.path_within_prefix(
                node.rest,
                @internal_link_base_prefix,
              ).nil?
            :sibling_path
          end
        end

        # The converter never knows the quoted post's source `original_id`, so
        # it records the source coordinates instead. A quote with a `post:` but
        # no `topic:` points into its own topic; a `topic:` with no `post:`
        # drops both coordinates, because the importer can only resolve them as
        # a pair.
        def defer_quote(node, source)
          post_number = node.post_number
          topic_id = post_number ? (node.topic_id || @topic_id) : nil

          @embeds.quote(
            quoted_username: node.username,
            quoted_name: node.name,
            quoted_topic_id: topic_id,
            quoted_post_number: post_number,
            original_markdown: source,
          )
        end
      end
    end
  end
end
