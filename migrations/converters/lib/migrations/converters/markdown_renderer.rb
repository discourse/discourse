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

      # Embeds deferred unless the caller narrows or extends the set. These always
      # need the import-time maps when present: uploads must be re-uploaded, quotes
      # reference foreign post/topic/user ids, mentions reference a foreign
      # username. `:link` is intentionally excluded by default — most URLs are
      # external and render fine; a converter that rewrites internal links opts in
      # explicitly with `defer:`.
      DEFAULT_DEFER = %i[upload quote mention].freeze

      # Maps a friendly embed kind to the Markbridge AST node class it overrides
      # and the extraction that feeds the sink. Each lambda returns the placeholder
      # token (the `EmbedBuffer#<kind>` call returns it), which Markbridge then
      # emits as the node's rendered output.
      def self.embed_handlers
        @embed_handlers ||= {
          upload: [
            Markbridge::AST::Upload,
            ->(sink, node, _iface) { sink.upload(upload_id: node.sha1) },
          ],
          quote: [
            Markbridge::AST::Quote,
            ->(sink, node, iface) do
              # Only the attribution carries the foreign post/topic/user reference
              # that needs remapping; the quoted body renders normally and the
              # closing tag stays in place. A quote with no such reference has
              # nothing to remap, so it renders natively (preserving its
              # attribution exactly). The token stands in for the opening
              # `[quote="…"]`, which PlaceholderResolver#render_quote rebuilds.
              unless node.post || node.topic || node.username
                next Markbridge::Renderers::Discourse::Tags::QuoteTag.new.render(node, iface)
              end

              token = sink.quote(quoted_post_id: node.post, quoted_username: node.username)
              content = iface.render_children(node, context: iface.with_parent(node))
              "\n\n#{token}\n#{content}\n[/quote]\n\n"
            end,
          ],
          mention: [
            Markbridge::AST::Mention,
            ->(sink, node, _iface) { sink.mention(mention_type: node.type.to_s, name: node.name) },
          ],
          link: [
            Markbridge::AST::Url,
            ->(sink, node, iface) { sink.link(url: node.href, text: iface.render_children(node)) },
          ],
        }
      end

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
            mapping[node_class] = Markbridge::Renderers::Discourse::Tag.new do |node, iface|
              extract.call(sink, node, iface)
            end
          end

        Markbridge.discourse_renderer(tags:)
      end
    end
  end
end
