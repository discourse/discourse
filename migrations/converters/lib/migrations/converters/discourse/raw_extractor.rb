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
      # We detect uploads, quote attributions, internal links, mentions, hashtags and
      # custom emoji. Polls and events are self-contained (no id remapping needed), so
      # they're left in `raw` verbatim.
      class RawExtractor
        Detectors = MarkdownScanner::Detectors

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

        # The stateless detectors, built fresh per extractor. The mention, hashtag
        # and custom-emoji detectors are not here: they're the ones configured with
        # state (the source's mention names, category/tag names and emoji names),
        # built below.
        DETECTORS = [Detectors::Upload, Detectors::UploadUrl, Detectors::Quote].freeze
        private_constant :DETECTORS

        # @param mention_resolver [#call] maps a mention name to its `mention_type`
        #   (a `MentionType` enum value for `here` / `all` / `group` / `user`).
        #   Defaults to a resolver with no group knowledge (so only `@here` / `@all`
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
        #   them the emoji detector — and its `:` trigger and gate — is left out, so
        #   posts don't pay for it.
        # @param internal_link_hosts [Set<String>, #include?] the source's own hosts
        #   (its base URL and any former domains), already downcased. An absolute link
        #   is treated as internal only when its host is one of these; relative links
        #   are always internal. Empty (the default) means relative-only detection.
        def initialize(
          mention_resolver: MentionResolver.new,
          mention_names: nil,
          hashtag_names: nil,
          custom_emoji_names: nil,
          internal_link_hosts: Set.new
        )
          @mention_resolver = mention_resolver

          detectors = DETECTORS.map(&:new)
          # After UploadUrl (index 1 of DETECTORS), so an upload URL still wins over a
          # bare internal link that happens to look like one.
          detectors << Detectors::InternalLink.new(hosts: internal_link_hosts)
          detectors << Detectors::Mention.new(names: mention_names)
          detectors << Detectors::Hashtag.new(names: hashtag_names)
          # The internal-link route segments always gate; the custom-emoji `:` gate is
          # OR'd in only when that detector is wired.
          extra_gates = [Detectors::InternalLink::GATE]

          if custom_emoji_names && !custom_emoji_names.empty?
            detectors << Detectors::Emoji.new(names: custom_emoji_names)
            extra_gates << Detectors::Emoji::GATE
          end

          extra_gate = Regexp.union(*extra_gates)

          # The detectors are stateless (the emoji one only reads a frozen name set)
          # and the scanner resets its state on each `scan`, so build them once and
          # reuse them for every post. The block reads `@sink` (set per call), so the
          # one scanner serves whatever buffer we're filling.
          @scanner =
            MarkdownScanner::Scanner.new(detectors:, extra_gate:) { |node| defer(node, @sink) }
        end

        # @param raw [String, nil] the source post body (Discourse Markdown).
        # @param on_embed [#upload, #quote, #link, #mention, #hashtag, #emoji] the
        #   embed sink.
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
          when MarkdownScanner::InternalLinkReference
            sink.link(
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
