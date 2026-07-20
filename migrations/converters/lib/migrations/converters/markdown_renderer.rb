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
        @embed_handlers ||= {
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
              unless node.post_number || node.topic_id || node.post_id || node.user_id ||
                       node.username
                next interface.render_default(node)
              end

              token =
                sink.quote(
                  quoted_post_id: bounded_id(node.post_id),
                  quoted_topic_id: bounded_id(node.topic_id),
                  quoted_post_number: bounded_id(node.post_number),
                  quoted_user_id: bounded_id(node.user_id),
                  quoted_username: node.username,
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
              # The normalizer has made the label legal CommonMark, but a legal
              # label can still hold an image, upload or attachment (a linked
              # image, which Discourse cooks fine). What's left to decide is
              # deferral:
              # only a label of plain text or simple inline formatting may be
              # recorded into the `text` column, because a deferrable embed
              # nested in a deferred label would mint its token into that
              # column, where the importer's single-pass substitution never
              # looks (false orphan, embed lost). Everything else renders
              # natively; a nested deferrable embed then tokenizes into the
              # raw where the importer resolves it (a mention degrades to
              # remapped plain text, which is all Discourse would cook inside
              # a link anyway).
              next interface.render_default(node) unless deferrable_label?(node)

              # A bare URL records no text, so the importer re-emits it bare
              # and autolinking/oneboxing keep working; `presence` catches a
              # blank label the same way (`[](url)` shows nothing).
              text = node.bare? ? nil : interface.render_children(node).presence
              sink.link(url: node.href, text:)
            end,
          ],
        }
      end

      # Markbridge attribution numbers are unbounded Integers, but the
      # IntermediateDB stores ids as SQLite signed 64-bit integers (binding a
      # bignum raises). A longer digit run is a numeric title or garbage, not a
      # real id — drop it and let the remaining attribution carry the quote,
      # mirroring the scanner's ID bound.
      def self.bounded_id(value)
        value if value && value < 10**18
      end
      private_class_method :bounded_id

      def self.label_formatting?(node)
        node.instance_of?(Markbridge::AST::Bold) || node.instance_of?(Markbridge::AST::Italic) ||
          node.instance_of?(Markbridge::AST::Strikethrough)
      end
      private_class_method :label_formatting?

      # Whether a link label contains only plain text and the inline formatting
      # Discourse allows inside `[…](url)`. This is the single policy point for
      # what a *deferred* link may carry. Extend deliberately: a kind qualifies
      # only if it renders inline (no blank lines) and is not deferrable itself.
      def self.deferrable_label?(node)
        node.children.all? { |child| deferrable_label_node?(child) }
      end
      private_class_method :deferrable_label?

      def self.deferrable_label_node?(node)
        case node
        when Markbridge::AST::Text, Markbridge::AST::MarkdownText
          true
        when Markbridge::AST::Code
          # Inline code is a code without a language (a language implies a
          # fenced block) and with a single line — multi-line code renders as
          # a block even without one.
          node.language.nil? && single_line_code?(node)
        else
          label_formatting?(node) && deferrable_label?(node)
        end
      end
      private_class_method :deferrable_label_node?

      def self.single_line_code?(node)
        node.children.all? do |child|
          child.instance_of?(Markbridge::AST::Text) && !child.text.include?("\n")
        end
      end
      private_class_method :single_line_code?

      # @param format [Symbol] one of {FORMATS}.
      def initialize(format: :bbcode)
        @format = format.to_sym
        raise UnknownFormat, "Unknown source format: #{format}" unless FORMATS.key?(@format)

        require FORMATS.fetch(@format)
      end

      # Markbridge's default rules cover CommonMark legality only: they unwrap a
      # link nested in a link and hoist block or multi-line-code content out of
      # an inline container. A linked image is legal CommonMark and Discourse
      # cooks it fine (the anchor simply wraps the image), so an image stays
      # inside its link — the defaults leave it alone and we add nothing for it.
      #
      # Our one rule turns a mention inside a link label into plain text.
      # Discourse doesn't cook mentions inside links, so nothing is lost — and as
      # text the label stays deferrable, so the link keeps its import-time
      # rewrite instead of falling back to native rendering. The trade: the name
      # is frozen source text, not remapped through the user map (fine for what
      # is label text either way).
      #
      # Built once; safe to share, the frozen normalizer keeps no per-run state.
      def self.normalizer
        @normalizer ||=
          Markbridge::Normalizer
            .default
            .rule(parent: Markbridge::AST::Url, child: Markbridge::AST::Mention, strategy: :textify)
            .freeze
      end

      # @param source [String] the source post body.
      # @param on_embed [#upload, #quote, #mention, #link, nil] the embed sink; when
      #   nil the embeds render natively.
      # @param defer [Array<Symbol>] which embed kinds to defer (default
      #   {DEFAULT_DEFER}). Ignored when `on_embed` is nil.
      # @return [String] Discourse Markdown.
      def to_markdown(source, on_embed: nil, defer: DEFAULT_DEFER)
        renderer = on_embed ? deferring_renderer(on_embed, defer) : nil
        Markbridge
          .convert(source, format: @format, renderer:, normalize: self.class.normalizer) do |ast|
            unwrap_self_links(ast)
          end
          .markdown
      end

      private

      # An image linked to its own source URL — the thumbnail-links-to-itself
      # pattern — is just noise: the anchor points where the image already
      # lives. Drop the link so the bare image gets Discourse's lightbox on
      # import. This runs in markbridge's parse-time yield hook, before
      # normalization, so the freed image is normalized like any other node.
      def unwrap_self_links(element)
        element.children.dup.each do |child|
          unwrap_self_links(child) if child.is_a?(Markbridge::AST::Element)

          image = self_link_image(child)
          element.replace_child(child, image) if image
        end
      end

      # The lone Image a self-link wraps, or nil when `node` is not a self-link:
      # a Url whose only non-whitespace child is an Image whose `src` is exactly
      # the link's href. Only Image carries a source URL to compare — Upload and
      # Attachment reference their target by sha1/id, not a URL, so they never
      # match here.
      def self_link_image(node)
        return unless node.is_a?(Markbridge::AST::Url)

        content = node.children.reject { |child| whitespace_text?(child) }
        return unless content.size == 1

        image = content.first
        image if image.is_a?(Markbridge::AST::Image) && image.src == node.href
      end

      def whitespace_text?(node)
        node.instance_of?(Markbridge::AST::Text) && node.text.strip.empty?
      end

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
