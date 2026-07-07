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
      # We detect uploads, quote attributions and mentions. Polls and events are
      # self-contained (no id remapping needed), so they're left in `raw` verbatim.
      class RawExtractor
        Detectors = MarkdownScanner::Detectors

        DETECTORS = [Detectors::Upload, Detectors::Quote, Detectors::Mention].freeze
        private_constant :DETECTORS

        # @param mention_resolver [#call] maps a mention name to its `mention_type`
        #   (`"here"` / `"all"` / `"group"` / `"user"`). Defaults to a resolver with
        #   no group knowledge (so only `@here` / `@all` are special-cased).
        def initialize(mention_resolver: MentionResolver.new)
          @mention_resolver = mention_resolver

          # The detectors are stateless and the scanner resets its state on each
          # `scan`, so build them once and reuse them for every post instead of a
          # fresh scanner, three detectors and a block per `extract`. The block reads
          # `@sink` (set per call), so the one scanner serves whatever buffer we're
          # filling.
          @scanner =
            MarkdownScanner::Scanner.new(detectors: DETECTORS.map(&:new)) do |node|
              defer(node, @sink)
            end
        end

        # @param raw [String, nil] the source post body (Discourse Markdown).
        # @param on_embed [#upload, #quote, #mention] the embed sink.
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
          when Markbridge::AST::Mention
            sink.mention(mention_type: @mention_resolver.call(node.name), name: node.name)
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
