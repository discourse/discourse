# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      # Extracts deferred embeds from a Discourse post's Markdown `raw` and replaces
      # each with a placeholder token, recording a typed descriptor on the given
      # embed sink (an {EmbedBuffer}). The importer's `PlaceholderResolver` rewrites
      # the tokens once the `original_id -> discourse_id` maps exist.
      #
      # The hard part of extracting from Markdown is *not* extracting from places
      # that only look like embeds — inside fenced/indented/inline code. That is
      # handled by {MarkdownScanner}, which we drive here: for each detected node we
      # record the embed on the sink and return the placeholder token the scanner
      # splices into the output.
      #
      # We detect uploads, quote attributions, mentions, hashtags and custom emoji.
      # Polls and events are self-contained (no id remapping needed), so they're left
      # in `raw` verbatim.
      class RawExtractor
        Detectors = MarkdownScanner::Detectors

        HashtagType = Migrations::Database::IntermediateDB::Enums::HashtagType
        private_constant :HashtagType

        # The forced type carried on a hashtag node (`:category` / `:tag`, from a
        # `::category` / `::tag` suffix) mapped to its stored enum value.
        FORCED_HASHTAG_TYPES = { category: HashtagType::CATEGORY, tag: HashtagType::TAG }.freeze
        private_constant :FORCED_HASHTAG_TYPES

        # The stateless detectors, built fresh per extractor. The hashtag and
        # custom-emoji detectors are not here: they're the ones configured with
        # state (the source's category/tag and emoji names), built below.
        DETECTORS = [
          Detectors::Upload,
          Detectors::UploadUrl,
          Detectors::Quote,
          Detectors::Mention,
        ].freeze
        private_constant :DETECTORS

        # @param mention_resolver [#call] maps a mention name to its `mention_type`
        #   (a `MentionType` enum value for `here` / `all` / `group` / `user`).
        #   Defaults to a resolver with no group knowledge (so only `@here` / `@all`
        #   are special-cased).
        # @param hashtag_names [Enumerable<String>, nil] the source's category slug
        #   paths and tag names (normalized). When given, only a hashtag naming one
        #   of them is extracted; anything else stays literal text. `nil` defers
        #   every hashtag that parses (the old syntactic behavior).
        # @param custom_emoji_names [Enumerable<String>, nil] the source's custom
        #   emoji names. When given (and non-empty) a `:name:` shortcode naming one
        #   of them is extracted; standard shortcodes always stay plain text. Without
        #   them the emoji detector — and its `:` trigger and gate — is left out, so
        #   posts don't pay for it.
        def initialize(
          mention_resolver: MentionResolver.new,
          hashtag_names: nil,
          custom_emoji_names: nil
        )
          @mention_resolver = mention_resolver

          detectors = DETECTORS.map(&:new)
          detectors << Detectors::Hashtag.new(names: hashtag_names)
          extra_triggers = []
          extra_gate = nil

          if custom_emoji_names && !custom_emoji_names.empty?
            detectors << Detectors::Emoji.new(names: custom_emoji_names)
            extra_triggers = [Detectors::Emoji::TRIGGER]
            extra_gate = Detectors::Emoji::GATE
          end

          # The detectors are stateless (the emoji one only reads a frozen name set)
          # and the scanner resets its state on each `scan`, so build them once and
          # reuse them for every post. The block reads `@sink` (set per call), so the
          # one scanner serves whatever buffer we're filling.
          @scanner =
            MarkdownScanner::Scanner.new(detectors:, extra_triggers:, extra_gate:) do |node|
              defer(node, @sink)
            end
        end

        # @param raw [String, nil] the source post body (Discourse Markdown).
        # @param on_embed [#upload, #quote, #mention, #hashtag, #emoji] the embed sink.
        # @param topic_id [Integer, nil] the source topic id of the containing post,
        #   used to complete a quote attribution that names a `post:` but no `topic:`
        #   (Discourse omits `topic:` when a post quotes another in the same topic).
        # @return [String, nil] the body with embeds replaced by placeholder tokens.
        def extract(raw, on_embed:, topic_id: nil)
          return raw if raw.nil?

          @sink = on_embed
          @topic_id = topic_id
          @scanner.scan(raw)
        end

        private

        # Records the detected embed on the sink and returns the placeholder token.
        def defer(node, sink)
          case node
          when Markbridge::AST::Upload
            sink.upload(upload_id: node.sha1)
          when MarkdownScanner::UploadUrlReference
            sink.upload(upload_id: node.sha1, original_markdown: node.original_markdown)
          when Markbridge::AST::Mention
            sink.mention(mention_type: @mention_resolver.call(node.name), name: node.name)
          when MarkdownScanner::HashtagReference
            sink.hashtag(hashtag_type: FORCED_HASHTAG_TYPES[node.forced_type], name: node.name)
          when MarkdownScanner::EmojiReference
            sink.emoji(name: node.name)
          when MarkdownScanner::QuoteAttribution
            defer_quote(node, sink)
          end
        end

        # The Discourse converter never knows the quoted post's source `original_id`,
        # so it records the source coordinates (topic id + post number) instead and
        # lets the importer resolve them. A quote with a `post:` but no `topic:`
        # points into its own topic. A quote with neither is username-only.
        def defer_quote(node, sink)
          post_number = node.post_number
          topic_id = post_number ? (node.topic_id || @topic_id) : nil

          sink.quote(
            quoted_username: node.username,
            quoted_topic_id: topic_id,
            quoted_post_number: post_number,
          )
        end
      end
    end
  end
end
