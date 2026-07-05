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
        end

        # @param raw [String, nil] the source post body (Discourse Markdown).
        # @param on_embed [#upload, #quote, #mention] the embed sink.
        # @return [String, nil] the body with embeds replaced by placeholder tokens.
        def extract(raw, on_embed:)
          return raw if raw.nil?

          scanner = MarkdownScanner::Scanner.new(detectors:) { |node| defer(node, on_embed) }
          scanner.scan(raw)
        end

        private

        def detectors
          DETECTORS.map(&:new)
        end

        # Records the detected embed on the sink and returns the placeholder token.
        def defer(node, sink)
          case node
          when Markbridge::AST::Upload
            sink.upload(upload_id: node.sha1)
          when Markbridge::AST::Mention
            sink.mention(mention_type: @mention_resolver.call(node.name), name: node.name)
          when MarkdownScanner::QuoteAttribution
            sink.quote(quoted_username: node.username, quoted_post_id: node.post)
          end
        end
      end
    end
  end
end
