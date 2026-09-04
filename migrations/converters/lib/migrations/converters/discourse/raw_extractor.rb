# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      # Extracts deferred embeds from a Discourse post's Markdown `raw` and replaces
      # each with a placeholder token, recording a typed descriptor on the embed
      # collector given at construction (an {EmbedBuffer}). The importer's `PlaceholderResolver`
      # rewrites the tokens once the `original_id -> discourse_id` maps exist.
      #
      # The hard part of extracting from Markdown is *not* extracting from places
      # that only look like embeds — inside fenced/indented/inline code, or in a
      # link's label or destination. A {MarkdownScanner::TierGate} classifies
      # every body first: most have nothing extractable and pass through
      # untouched, the rest go to the {MarkdownScanner::EngineScanner}, where
      # the real discourse-markdown-it parse decides what is code and what is a
      # link. For each detected node we record the embed on the collector and
      # return the placeholder token the scanner splices into the output.
      #
      # We detect uploads, quote references, internal links, mentions, hashtags and
      # custom emoji. Polls and events are self-contained (no id remapping needed), so
      # they're left in `raw` verbatim.
      class RawExtractor
        # A body normalized and classified once, ready for bounded batch scanning
        # and later extraction with the matching scan data.
        PreparedBody =
          Data.define(:id, :raw, :topic_id, :tier) do
            def engine_bound?
              tier == :engine
            end
          end

        # The measured throughput sweet spot is 32 ordinary posts per V8 call.
        # The byte cap prevents those calls from becoming arbitrarily large;
        # one body over the cap still runs alone so valid large posts are not
        # rejected merely because they cannot be batched.
        DEFAULT_BATCH_POSTS = 32
        DEFAULT_BATCH_BYTES = 4 * 1024 * 1024

        Constructs = MarkdownScanner::Constructs
        private_constant :Constructs

        HashtagType = Migrations::Database::IntermediateDB::Enums::HashtagType
        private_constant :HashtagType

        LinkTarget = Migrations::Database::IntermediateDB::Enums::LinkTarget
        private_constant :LinkTarget

        # The forced type carried on a hashtag node (`:category` / `:tag`, from a
        # `::category` / `::tag` suffix) mapped to its stored enum value.
        FORCED_HASHTAG_TYPES = { category: HashtagType::CATEGORY, tag: HashtagType::TAG }.freeze
        private_constant :FORCED_HASHTAG_TYPES

        # The symbol a {Constructs::InternalLink} node carries for its target kind
        # mapped to the stored `link_target` enum value.
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

        # @param embeds [#upload, #quote, #link, #mention, #hashtag, #emoji] the
        #   embed collector.
        # @param mention_classifier [#call] maps a mention name to its `mention_type`
        #   (a `MentionType` enum value for `here` / `all` / `group` / `user`).
        #   Defaults to a classifier with no group knowledge (so only `@here` / `@all`
        #   are special-cased).
        # @param mention_names [Migrations::CompactStringSet] the source's mention
        #   names (usernames, group names, the `here_mention` value and `all`,
        #   normalized). Only a mention naming one of them is deferred; anything else
        #   stays literal text. Required: without the names every `@word` that parses
        #   is rewritten, including the ones that name nobody.
        # @param hashtag_names [Migrations::CompactStringSet] the source's category
        #   slug paths and tag names (normalized). Only a hashtag naming one of them
        #   is extracted; anything else stays literal text. Required for the same
        #   reason as `mention_names`.
        # @param custom_emoji_names [Enumerable<String>, nil] the source's custom
        #   emoji names, in any spelling — they are folded here, like the mention
        #   and hashtag names arrive folded. When given (and non-empty) a `:name:`
        #   shortcode naming one of them is extracted whatever case the author
        #   wrote it in (core lowercases a shortcode before its own lookup);
        #   standard shortcodes always stay plain text. Without them the emoji
        #   construct is left out entirely, so posts don't pay for its `:` trigger.
        # @param internal_link_hosts [Hash{String => (String, nil)}] the source's own
        #   hosts (its base URL and any former domains), each downcased and mapped to
        #   its path prefix — `"/forum"` for a subdirectory install (no trailing
        #   slash), or `nil` for a root install. Different hosts may carry different
        #   prefixes (a former root domain that later moved into a subfolder). An
        #   absolute link is internal only when its host is a key here AND, for a
        #   prefixed host, its path sits inside that prefix; on a root-install host
        #   every path belongs to the forum. A relative link is internal wherever it is
        #   a real link (link syntax or a bare URL reached at a `](…)` target); a
        #   relative URL bare in prose stays literal, since it isn't a link once
        #   cooked. With the map empty (the default), only relative links are detected.
        # @param internal_link_base_prefix [String, nil] the current site's own path
        #   prefix, for relative links: on a subfolder install a relative internal link
        #   is written with the prefix (`/forum/t/slug/5`), so the prefix is stripped
        #   before the route is parsed. `nil` (the default) for a root install.
        # @param on_foreign_host [#call, nil] called with the host of an absolute,
        #   internal-looking link whose host is not in `internal_link_hosts` — a hint
        #   that a former domain may be missing from the source_site settings. Each
        #   host is reported once per extractor. Nil (the default) skips the signal.
        # @param markdown_engine [MarkdownEngine::Context] the engine context for
        #   `:engine`-classified bodies: extraction from context-sensitive
        #   bodies is checked by count matching against the real
        #   discourse-markdown-it parse, escalating to per-occurrence marker
        #   substitution, and whatever stays unconfirmed is left verbatim (see
        #   {MarkdownScanner::EngineScanner}). Build it after the worker
        #   forks — V8 contexts do not survive forking.
        # @param on_engine_refusal [#call, nil] called with the cause (a Symbol)
        #   and its diagnostic detail (the exception class name for
        #   `:engine_error`, else nil) whenever an `:engine` body keeps at least
        #   one unconfirmed construct; the tallies are also kept on
        #   {#engine_refusals}. The caller knows which post it is extracting,
        #   so post identity stays on its side of the callback.
        # @param slow_timeout_ms [Integer, nil] the retry ceiling for a body
        #   whose parse the engine terminated at the fast default: the body is
        #   parsed once more with this ceiling before `:engine_error` is
        #   recorded. A conversion runs once, so the extra time is acceptable.
        #   `nil` disables the retry.
        # @param on_slow_parse [#call, nil] called with no arguments (as with
        #   `on_engine_refusal`, the post identity stays on the caller's side)
        #   whenever a body's parse only succeeded on the slow retry; the count
        #   is also kept on {#slow_parses}. Such bodies are recovered, not
        #   refused — but they will cook just as pathologically on the
        #   destination site, so a conversion may want their ids.
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
          # After UploadUrl, so an upload URL still wins over a bare internal link that
          # happens to look like one.
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
          # state on each `scan`, so build them once and reuse them for every
          # post. `extract` swaps `@topic_id` per call, so one extractor must not
          # run in two threads at once — each worker holds its own (a future
          # posts step is expected to build it in per-worker `setup`; no
          # production step exists yet).
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
        # least one unconfirmed construct. Those constructs stayed verbatim, so
        # their references are stale until someone resolves them. The causes
        # fall into four groups, and only the first should read as a problem
        # with the extraction itself:
        #
        #   * unexpected failure — `:unanchored` (the engine recognized a tracked
        #     occurrence, but no construct grammar could place it),
        #     `:engine_error`, `:overlap`;
        #   * known unsupported source content — `:invalid_internal_route` (a
        #     coordinate-shaped path that parses no route, usually a link that
        #     was already broken on the source), `:count_mismatch`, `:entity`,
        #     `:cr_line_endings` (genuinely ambiguous spellings the passes
        #     refuse rather than guess);
        #   * budget — `:substitution_limit`, `:substitution_budget`,
        #     `:url_volume`, `:name_volume` (bounded work on pathological
        #     bodies);
        #   * the rest of a partially extracted body (the confirmed constructs
        #     were still replaced).
        attr_reader :engine_refusals

        # How many bodies parsed only on the slow retry. They extracted fine —
        # this is a heads-up count, not part of the must-resolve list.
        attr_reader :slow_parses

        # @param raw [String, nil] the source post body (Discourse Markdown).
        # @param topic_id [Integer, nil] the source topic id of the containing post,
        #   used to complete a quote reference that names a `post:` but no `topic:`
        #   (Discourse omits `topic:` when a post quotes another in the same topic).
        # @return [String, nil] the body with embeds replaced by placeholder tokens.
        #   Invalid bytes are scrubbed first (and non-UTF-8 encodings converted), and
        #   the returned body is built from that normalized string: the gate, the
        #   engine and every byte offset must all read the same bytes, so exactly one
        #   normalization happens, here at the top.
        def extract(raw, topic_id: nil)
          extract_prepared(prepare(raw:, topic_id:))
        end

        # Normalizes and classifies one body. A batching caller prepares each
        # body once, passes the resulting values to {#scan_batches}, then calls
        # {#extract_prepared} with the scan data keyed by id.
        def prepare(raw:, id: nil, topic_id: nil)
          return PreparedBody.new(id:, raw:, topic_id:, tier: :none) if raw.nil?

          normalized = normalize_input(raw)
          PreparedBody.new(id:, raw: normalized, topic_id:, tier: @gate.classify(normalized))
        end

        # Scans prepared engine-bound bodies, partitioning them by both count
        # and aggregate bytes. Returns scan data keyed by id. If one partition
        # terminates, only that partition returns no data; its bodies recover
        # through the normal per-body path in {#extract_prepared}.
        #
        # The per-call V8 overhead (~0.5ms) is comparable to an average parse.
        # On a real 1.5M-post corpus at 18 workers, batches of 32 measured 45.2s
        # wall / 360.4s V8 against 70.9s / 684.4s unbatched.
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

        # Extracts a prepared body, using its matching precomputed scan data
        # when supplied. The same normalized bytes feed the gate, engine offsets,
        # construct locators, and final splicing.
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

        # An unconfirmed construct stays verbatim — count matching and marker
        # substitution may fail to place it, and a wrong placement would
        # corrupt the post while verbatim only leaves its reference stale.
        # The confirmed constructs in the same body are still
        # extracted; the cause is counted and reported so a conversion
        # surfaces how many posts (and why) still need resolution.
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

        # Records the detected embed on the collector and returns the placeholder
        # token. `source` is the verbatim matched slice; it is stored on every row so
        # the importer can restore the exact source text when the embed can't be
        # mapped, instead of rebuilding a canonical form.
        def defer(node, source)
          case node
          when Markbridge::AST::Upload
            @embeds.upload(upload_id: node.sha1, original_markdown: source)
          when MarkdownScanner::UploadUrlReference
            ownership = upload_ownership(node)
            # A relative path outside the base prefix belongs to another
            # application on the same server. There is no host to allowlist,
            # so it is not recorded at all and the source text stays.
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

        # Whether a full-URL upload is the source's own. Returns nil when it
        # is; the host string when it is not (the importer maps such a row's
        # sha1 only against an explicit allowlist — a foreign basename that
        # collides with a source upload sha1 must not be rewritten to the
        # imported file); `:sibling_path` for a relative URL outside the base
        # prefix. The path prefix matters on a subdirectory install:
        # `https://example.com/other/uploads/…` shares the forum's host but
        # belongs to a different application, so its sha1 is not the source's.
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

        # The Discourse converter never knows the quoted post's source `original_id`,
        # so it records the source coordinates (topic id + post number) instead and
        # lets the importer resolve them. A quote with a `post:` but no `topic:`
        # points into its own topic. A `topic:` with no `post:` drops both coordinates,
        # because the importer can only resolve them as a pair. A quote with neither is
        # username-only.
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
