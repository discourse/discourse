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
        Detectors = MarkdownScanner::Detectors
        private_constant :Detectors

        HashtagType = Migrations::Database::IntermediateDB::Enums::HashtagType
        private_constant :HashtagType

        LinkTarget = Migrations::Database::IntermediateDB::Enums::LinkTarget
        private_constant :LinkTarget

        # The forced type carried on a hashtag node (`:category` / `:tag`, from a
        # `::category` / `::tag` suffix) mapped to its stored enum value.
        FORCED_HASHTAG_TYPES = { category: HashtagType::CATEGORY, tag: HashtagType::TAG }.freeze
        private_constant :FORCED_HASHTAG_TYPES

        # The symbol an {Detectors::InternalLink} node carries for its target kind
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
        #   emoji names. When given (and non-empty) a `:name:` shortcode naming one
        #   of them is extracted; standard shortcodes always stay plain text. Without
        #   them the emoji detector is left out entirely, so posts don't pay for its
        #   `:` trigger.
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
        #   `:engine`-classified bodies: extraction from context-sensitive bodies
        #   is certified against the real discourse-markdown-it parse, escalating
        #   to per-occurrence trial substitution, and whatever stays unproven is
        #   left verbatim (see {MarkdownScanner::EngineScanner}). Build it after
        #   the worker forks — V8 contexts do not survive forking.
        # @param on_engine_refusal [#call, nil] called with the cause (a Symbol)
        #   and its diagnostic detail (the exception class name for
        #   `:engine_error`, else nil) whenever an `:engine` body keeps at least
        #   one unproven construct; the tallies are also kept on
        #   {#engine_refusals}. The caller knows which
        #   post it is extracting, so post identity stays on its side of the
        #   callback.
        # @param slow_timeout_ms [Integer, nil] the retry ceiling for a body
        #   whose parse the engine terminated at the fast default: the body is
        #   parsed once more under this ceiling before `:engine_error` is
        #   recorded — a conversion runs once, so a patient minute beats stale
        #   references. `nil` disables the retry.
        # @param on_slow_parse [#call, nil] called (with no arguments, like
        #   `on_engine_refusal` the post identity stays on the caller's side)
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
          @on_engine_refusal = on_engine_refusal
          @on_slow_parse = on_slow_parse
          @engine_refusals = Hash.new(0)
          @slow_parses = 0

          detectors = [Detectors::Upload.new, Detectors::UploadUrl.new, Detectors::Quote.new]
          # After UploadUrl, so an upload URL still wins over a bare internal link that
          # happens to look like one.
          detectors << Detectors::InternalLink.new(
            hosts: internal_link_hosts,
            base_prefix: internal_link_base_prefix,
            on_foreign_host:,
          )
          detectors << Detectors::Mention.new(names: mention_names)
          detectors << Detectors::Hashtag.new(names: hashtag_names)
          if custom_emoji_names.present?
            detectors << Detectors::Emoji.new(names: custom_emoji_names)
          end

          # The detectors carry no per-post state (the internal-link one only
          # accumulates its report-once host set) and the scanner resets its
          # state on each `scan`, so build them once and reuse them for every
          # post. `extract` swaps `@topic_id` per call, so one extractor must not
          # run in two threads at once — each worker holds its own (the posts
          # step builds it in per-worker `setup`).
          on_node = ->(node, source) { defer(node, source) }
          @gate = MarkdownScanner::TierGate.new(detectors:)
          @engine_scanner =
            MarkdownScanner::EngineScanner.new(
              engine: markdown_engine,
              detectors:,
              gate: @gate,
              mention_names:,
              hashtag_names:,
              custom_emoji_names:,
              internal_link_hosts:,
              internal_link_base_prefix:,
              slow_timeout_ms:,
              &on_node
            )
        end

        # Cause tallies (`cause => count`) for `:engine` bodies that kept at
        # least one unproven construct. Those constructs stayed verbatim, so
        # their references are stale until someone resolves them — this tally
        # is the conversion's must-resolve list.
        attr_reader :engine_refusals

        # How many bodies parsed only on the slow retry. They extracted fine —
        # this is a heads-up count, not part of the must-resolve list.
        attr_reader :slow_parses

        # @param raw [String, nil] the source post body (Discourse Markdown).
        # @param topic_id [Integer, nil] the source topic id of the containing post,
        #   used to complete a quote reference that names a `post:` but no `topic:`
        #   (Discourse omits `topic:` when a post quotes another in the same topic).
        # @param scan_data [Hash, nil] a precomputed `MarkdownEngine::Context#scan`
        #   element for this body, from a caller that batched several bodies into
        #   one engine call (see {#engine_bound?}). Used only when normalization
        #   leaves the body byte-identical — otherwise the engine saw different
        #   bytes than every offset here would read, so the data is ignored and
        #   the body is scanned live.
        # @return [String, nil] the body with embeds replaced by placeholder tokens.
        #   Invalid bytes are scrubbed first (and non-UTF-8 encodings converted), and
        #   the returned body is built from that normalized string: the gate, the
        #   engine and every byte offset must all read the same bytes, so exactly one
        #   normalization happens, here at the top.
        def extract(raw, topic_id: nil, scan_data: nil)
          return raw if raw.nil?

          @topic_id = topic_id
          normalized = normalize_input(raw)
          scan_data = nil unless normalized.equal?(raw)

          @gate.classify(normalized) == :none ? normalized : extract_engine(normalized, scan_data)
        end

        # Whether `raw` would take the engine path — for a caller that wants to
        # batch several bodies into one `MarkdownEngine::Context#scan` call and
        # pass each result back via `extract(..., scan_data:)`.
        def engine_bound?(raw)
          return false if raw.nil?

          @gate.classify(normalize_input(raw)) == :engine
        end

        # One V8 call for several engine-bound bodies (`{ id:, raw: }` each),
        # returning scan data keyed by id for `extract(..., scan_data:)`. One
        # pathological body terminates the whole batched call, so a failed
        # batch returns no data at all — each of its bodies then takes the
        # normal per-body ladder (fast attempt, slow retry, refusal) — and the
        # engine is reset so the next call gets a healthy context.
        # Process/resource failures are deliberately not rescued, mirroring
        # the per-body policy.
        def scan_batch(posts)
          @markdown_engine.scan(posts).index_by { |data| data["id"] }
        rescue MiniRacer::ScriptTerminatedError, MiniRacer::RuntimeError
          @markdown_engine.reset!
          {}
        end

        private

        def normalize_input(raw)
          if raw.encoding == Encoding::UTF_8
            raw.valid_encoding? ? raw : raw.scrub
          else
            raw.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
          end
        end

        # An unproven construct stays verbatim — certification and trial
        # substitution can prove themselves unable to place it, and a wrong
        # placement would corrupt the post while verbatim only leaves its
        # reference stale. The proven constructs in the same body are still
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
        # token. `source` is the verbatim matched slice; it rides on every row so
        # the importer can restore the exact source text when the embed can't be
        # mapped, instead of rebuilding a canonical form.
        def defer(node, source)
          case node
          when Markbridge::AST::Upload
            @embeds.upload(upload_id: node.sha1, original_markdown: source)
          when MarkdownScanner::UploadUrlReference
            @embeds.upload(upload_id: node.sha1, original_markdown: source)
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
            @embeds.emoji(name: node.name, original_markdown: source)
          when MarkdownScanner::QuoteReference
            defer_quote(node, source)
          else
            raise NotImplementedError, "no defer handler for #{node.class}"
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
