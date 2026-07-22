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
      # that only look like embeds — inside fenced/indented/inline code. That is
      # handled by {MarkdownScanner}, which we drive here: for each detected node we
      # record the embed on the collector and return the placeholder token the
      # scanner splices into the output.
      #
      # We detect uploads, quote attributions, internal links, mentions, hashtags and
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
        }.freeze
        private_constant :LINK_TARGET_TYPES

        # @param embeds [#upload, #quote, #link, #mention, #hashtag, #emoji] the
        #   embed collector.
        # @param mention_classifier [#call] maps a mention name to its `mention_type`
        #   (a `MentionType` enum value for `here` / `all` / `group` / `user`).
        #   Defaults to a classifier with no group knowledge (so only `@here` / `@all`
        #   are special-cased).
        # @param mention_names [Migrations::SortedStringSet, nil] the source's
        #   mention names (usernames, group names, the `here_mention` value and
        #   `all`, normalized). When given, only a mention naming one of them is
        #   deferred; anything else stays literal text. `nil` defers every `@word`
        #   that parses (the old syntactic behavior).
        # @param hashtag_names [Migrations::SortedStringSet, nil] the source's
        #   category slug paths and tag names (normalized). When given, only a
        #   hashtag naming one of them is extracted; anything else stays literal
        #   text. `nil` defers every hashtag that parses (the old syntactic behavior).
        # @param custom_emoji_names [Enumerable<String>, nil] the source's custom
        #   emoji names. When given (and non-empty) a `:name:` shortcode naming one
        #   of them is extracted; standard shortcodes always stay plain text. Without
        #   them the emoji detector is left out entirely, so posts don't pay for its
        #   `:` trigger.
        # @param internal_link_hosts [Set<String>, #include?] the source's own hosts
        #   (its base URL and any former domains), already downcased. An absolute link
        #   is treated as internal only when its host is one of these; relative links
        #   are always internal. Empty (the default) means relative-only detection.
        # @param on_foreign_host [#call, nil] called with the host of an absolute,
        #   internal-looking link whose host is not in `internal_link_hosts` — a hint
        #   that a former domain may be missing from the source_site settings. Nil (the
        #   default) skips the signal.
        def initialize(
          embeds:,
          mention_classifier: MentionClassifier.new,
          mention_names: nil,
          hashtag_names: nil,
          custom_emoji_names: nil,
          internal_link_hosts: Set.new,
          on_foreign_host: nil
        )
          @embeds = embeds
          @mention_classifier = mention_classifier

          detectors = [Detectors::Upload.new, Detectors::UploadUrl.new, Detectors::Quote.new]
          # After UploadUrl, so an upload URL still wins over a bare internal link that
          # happens to look like one.
          detectors << Detectors::InternalLink.new(hosts: internal_link_hosts, on_foreign_host:)
          detectors << Detectors::Mention.new(names: mention_names)
          detectors << Detectors::Hashtag.new(names: hashtag_names)
          if custom_emoji_names.present?
            detectors << Detectors::Emoji.new(names: custom_emoji_names)
          end

          # The detectors are stateless (the emoji one only reads a frozen name set)
          # and the scanner resets its state on each `scan`, so build them once and
          # reuse them for every post. `extract` swaps `@topic_id` per call, so one
          # extractor must not run in two threads at once — each worker holds its own
          # (the posts step builds it in per-worker `setup`).
          @scanner = MarkdownScanner::Scanner.new(detectors:) { |node| defer(node) }
        end

        # @param raw [String, nil] the source post body (Discourse Markdown).
        # @param topic_id [Integer, nil] the source topic id of the containing post,
        #   used to complete a quote attribution that names a `post:` but no `topic:`
        #   (Discourse omits `topic:` when a post quotes another in the same topic).
        # @return [String, nil] the body with embeds replaced by placeholder tokens.
        def extract(raw, topic_id: nil)
          return raw if raw.nil?

          @topic_id = topic_id
          @scanner.scan(raw)
        end

        private

        # Records the detected embed on the collector and returns the placeholder token.
        def defer(node)
          case node
          when Markbridge::AST::Upload
            @embeds.upload(upload_id: node.sha1)
          when MarkdownScanner::UploadUrlReference
            @embeds.upload(upload_id: node.sha1, original_markdown: node.original_markdown)
          when Markbridge::AST::Mention
            @embeds.mention(mention_type: @mention_classifier.call(node.name), name: node.name)
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
            )
          when MarkdownScanner::HashtagReference
            @embeds.hashtag(hashtag_type: FORCED_HASHTAG_TYPES[node.forced_type], name: node.name)
          when MarkdownScanner::EmojiReference
            @embeds.emoji(name: node.name)
          when MarkdownScanner::QuoteAttribution
            defer_quote(node)
          else
            # A new detector whose node type isn't handled here would otherwise fall
            # through and — via the scanner's nil-return passthrough — leave the
            # matched text in place silently. Fail loudly instead.
            raise NotImplementedError, "no defer handler for #{node.class}"
          end
        end

        # The Discourse converter never knows the quoted post's source `original_id`,
        # so it records the source coordinates (topic id + post number) instead and
        # lets the importer resolve them. A quote with a `post:` but no `topic:`
        # points into its own topic. A `topic:` with no `post:` drops both coordinates,
        # because the importer can only resolve them as a pair. A quote with neither is
        # username-only.
        def defer_quote(node)
          post_number = node.post_number
          topic_id = post_number ? (node.topic_id || @topic_id) : nil

          @embeds.quote(
            quoted_username: node.username,
            quoted_name: node.name,
            quoted_topic_id: topic_id,
            quoted_post_number: post_number,
          )
        end
      end
    end
  end
end
