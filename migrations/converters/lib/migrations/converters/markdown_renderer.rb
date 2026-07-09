# frozen_string_literal: true

require "markbridge"

module Migrations
  module Converters
    # Convert-time wrapper over the Markbridge gem: renders a source forum's post
    # markup (BBCode, HTML, MediaWiki, TextFormatter XML) into Discourse Markdown,
    # optionally deferring the embeds that cannot be finalized until import time.
    #
    # When an `on_embed` sink (an {EmbedBuffer}, or anything answering the embed
    # callbacks) is passed, the configured embed node types are not rendered
    # inline: each is recorded on the sink and replaced in the output by a
    # placeholder token (see {Migrations::Placeholder}). Everything else renders
    # natively. With no sink, it just renders the source to Markdown.
    #
    # Markbridge does not parse Markdown, so a Discourse -> Discourse migration
    # (whose `raw` is already Markdown) does not use this; this renderer is for
    # forums whose post bodies are in one of the formats above.
    #
    # @example deferring uploads and quotes into an EmbedBuffer
    #   buffer = EmbedBuffer.new(owner_type: Enums::EmbedOwner::POST)
    #   raw = MarkdownRenderer.new(format: :bbcode).to_markdown(item[:body], on_embed: buffer)
    #   # `raw` now carries placeholder tokens; `buffer.uploads` / `buffer.quotes`
    #   # hold the typed linkage descriptors.
    class MarkdownRenderer
      class UnknownFormat < StandardError
      end

      # The `require` path for each supported source format. HTML / MediaWiki /
      # TextFormatter additionally need nokogiri (provided by the host
      # application); BBCode has no extra dependency.
      FORMATS = {
        bbcode: "markbridge/bbcode",
        html: "markbridge/html",
        mediawiki: "markbridge/mediawiki",
        text_formatter_xml: "markbridge/textformatter",
      }.freeze

      # Embeds deferred unless the caller narrows or extends the set. These three
      # can't be finalized at convert time: an upload must first exist on the
      # destination, an attributed quote references a source post the import
      # renumbers, and a mention names a user a merge may rename — only the
      # import-time maps settle them.
      #
      # `:link` is excluded by default because this generic handler records only
      # `url` and `text`; telling an internal link from an external one takes
      # source-specific URL parsing. With a plain EmbedBuffer, deferring links just
      # round-trips every link through the database unchanged. A converter that
      # wants internal links rewritten opts in with `defer:` and supplies a sink
      # whose `link` callback classifies the URL and records the target fields.
      DEFAULT_DEFER = %i[upload quote mention].freeze

      # Markbridge types a mention as `:user` or `:group`; map that to the
      # `MentionType` enum stored on `embed_mentions`. It knows no `here`/`all`, so
      # those don't arise on this path.
      MENTION_TYPES = {
        user: Migrations::Database::IntermediateDB::Enums::MentionType::USER,
        group: Migrations::Database::IntermediateDB::Enums::MentionType::GROUP,
      }.freeze
      private_constant :MENTION_TYPES

      # Maps a friendly embed kind to the Markbridge AST node class it overrides
      # and the extraction that feeds the sink. Each lambda returns the placeholder
      # token (the `EmbedBuffer#<kind>` call returns it), which Markbridge then
      # emits as the node's rendered output.
      def self.embed_handlers
        @embed_handlers ||= build_embed_handlers
      end

      def self.build_embed_handlers
        # The stock QuoteTag renders a quote natively when its attribution carries
        # nothing to remap. Markbridge has no fall-through to an overridden tag
        # (the override replaces the library entry), so we delegate to our own
        # instance — stateless, hence shared.
        quote_tag = Markbridge::Renderers::Discourse::Tags::QuoteTag.new

        {
          upload: [
            Markbridge::AST::Upload,
            ->(sink, node, _interface) { sink.upload(upload_id: node.sha1) },
          ],
          quote: [
            Markbridge::AST::Quote,
            ->(sink, node, interface) do
              # Only the attribution carries the foreign post/topic/user reference
              # that needs remapping; the quoted body renders normally and the
              # closing tag stays in place. A quote with no such reference has
              # nothing to remap, so it renders natively (preserving its
              # attribution exactly). The token stands in for the opening
              # `[quote="…"]`, which PlaceholderResolver#render_quote rebuilds.
              next quote_tag.render(node, interface) unless node.post || node.topic || node.username

              # Markbridge parses the Discourse attribution format, where `post:`
              # is a post number and `topic:` a topic id — source coordinates,
              # not a post id. Its Quote node carries no user id, so
              # `quoted_user_id` can't be filled on this path.
              token =
                sink.quote(
                  quoted_username: node.username,
                  quoted_topic_id: node.topic&.to_i,
                  quoted_post_number: node.post&.to_i,
                )
              content = interface.render_children(node, context: interface.with_parent(node))
              "\n\n#{token}\n#{content}\n[/quote]\n\n"
            end,
          ],
          mention: [
            Markbridge::AST::Mention,
            ->(sink, node, _interface) do
              sink.mention(mention_type: MENTION_TYPES[node.type], name: node.name)
            end,
          ],
          link: [
            Markbridge::AST::Url,
            ->(sink, node, interface) do
              # `presence`: an empty text must be recorded as nil (a bare URL),
              # not "" — the importer would render "" as `[](url)`.
              sink.link(url: node.href, text: interface.render_children(node).presence)
            end,
          ],
        }
      end
      private_class_method :build_embed_handlers

      # @param format [Symbol] one of {FORMATS}.
      def initialize(format: :bbcode)
        @format = format.to_sym
        raise UnknownFormat, "Unknown source format: #{format}" unless FORMATS.key?(@format)

        require FORMATS.fetch(@format)
      end

      # @param source [String] the source post body.
      # @param on_embed [#upload, #quote, #mention, #link, nil] the embed sink; when
      #   nil the embeds render natively.
      # @param defer [Array<Symbol>] which embed kinds to defer (default
      #   {DEFAULT_DEFER}). Ignored when `on_embed` is nil.
      # @return [String] Discourse Markdown.
      def to_markdown(source, on_embed: nil, defer: DEFAULT_DEFER)
        renderer = on_embed ? deferring_renderer(on_embed, defer) : nil
        Markbridge.convert(source, format: @format, renderer:).markdown
      end

      private

      def deferring_renderer(sink, defer)
        tags =
          Array(defer).each_with_object({}) do |kind, mapping|
            node_class, extract = self.class.embed_handlers.fetch(kind)
            mapping[node_class] = Markbridge::Renderers::Discourse::Tag.new do |node, interface|
              extract.call(sink, node, interface)
            end
          end

        Markbridge.discourse_renderer(tags:)
      end
    end
  end
end
