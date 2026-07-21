# frozen_string_literal: true

require "markbridge"

module Migrations
  module Converters
    # Convert-time wrapper over the Markbridge gem: renders a source forum's post
    # markup (BBCode, HTML, MediaWiki, TextFormatter XML) into Discourse Markdown,
    # optionally deferring the embeds that cannot be finalized until import time.
    #
    # When an embed collector (an {EmbedBuffer}, or anything that responds to
    # the embed callbacks) is passed via `embeds:`, the configured embed node types are not
    # rendered inline: each is recorded on the collector and replaced in the output
    # by a placeholder token (see {Migrations::Placeholder}). Everything else
    # renders natively. With no collector, it just renders the source to Markdown.
    #
    # Markbridge does not parse Markdown, so a Discourse -> Discourse migration
    # (whose `raw` is already Markdown) does not use this; this renderer is for
    # forums whose post bodies are in one of the formats above.
    #
    # @example deferring uploads and quotes into an EmbedBuffer
    #   buffer = EmbedBuffer.new(owner_type: Enums::EmbedOwner::POST)
    #   raw = MarkdownRenderer.new(format: :bbcode).to_markdown(item[:body], embeds: buffer)
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
      # renumbers, and a mention names a user a merge may rename — they can only be
      # resolved at import time, using the import maps.
      #
      # `:link` is excluded by default because this generic handler records only
      # `url` and `text`; telling an internal link from an external one takes
      # source-specific URL parsing. With a plain EmbedBuffer, deferring links just
      # round-trips every link through the database unchanged. A converter that
      # wants internal links rewritten opts in with `defer:` and supplies a
      # collector whose `link` callback classifies the URL and records the target
      # fields.
      DEFAULT_DEFER = %i[upload quote mention].freeze

      # Markbridge types a mention as `:user` or `:group`; map that to the
      # `MentionType` enum stored on `embed_mentions`. Markbridge has no
      # `here`/`all` mention types, so they never show up here.
      MENTION_TYPES = {
        user: Migrations::Database::IntermediateDB::Enums::MentionType::USER,
        group: Migrations::Database::IntermediateDB::Enums::MentionType::GROUP,
      }.freeze
      private_constant :MENTION_TYPES

      # Maps each deferrable embed kind to the Markbridge AST node class it
      # overrides and the class method that records it on the collector. Each
      # method returns the placeholder token, which Markbridge then emits as the
      # node's rendered output.
      def self.embed_handlers
        @embed_handlers ||= {
          upload: [Markbridge::AST::Upload, method(:defer_upload)],
          quote: [Markbridge::AST::Quote, method(:defer_quote)],
          mention: [Markbridge::AST::Mention, method(:defer_mention)],
          link: [Markbridge::AST::Url, method(:defer_link)],
        }
      end

      def self.defer_upload(collector, node, _interface)
        collector.upload(upload_id: node.sha1)
      end
      private_class_method :defer_upload

      def self.defer_quote(collector, node, interface)
        # Only the attribution carries the foreign post/topic/user reference that
        # needs remapping; the quoted body renders normally and the closing tag
        # stays in place. A quote attributed only by a display name (`author`) has
        # nothing to remap, so it renders natively and keeps that attribution as
        # written. The token stands in for the opening `[quote="…"]`, which
        # PlaceholderResolver#render_quote rebuilds.
        return interface.render_default(node) unless attributed?(node)

        token =
          collector.quote(
            quoted_post_id: storable_id(node.post_id),
            quoted_topic_id: storable_id(node.topic_id),
            quoted_post_number: storable_id(node.post_number),
            quoted_user_id: storable_id(node.user_id),
            quoted_username: node.username,
            # The BBCode parser copies the leading token into both author and
            # username, so recording that as a name too would just repeat the
            # username. Keep the name only when it is distinct.
            quoted_name: (node.author unless node.author == node.username),
          )
        content = interface.render_children(node, context: interface.with_parent(node))
        "\n\n#{token}\n#{content}\n[/quote]\n\n"
      end
      private_class_method :defer_quote

      def self.defer_mention(collector, node, _interface)
        collector.mention(mention_type: MENTION_TYPES[node.type], name: node.name)
      end
      private_class_method :defer_mention

      def self.defer_link(collector, node, interface)
        # After normalization the only deferrable embed a label can still hold is
        # an upload or attachment — a linked image, which is legal and Discourse
        # cooks fine. What is left to decide is deferral. Only a label of plain
        # text or simple inline formatting may be recorded into the `text` column.
        # If the label contained a deferrable embed, its placeholder would be
        # recorded into the `text` column — but the importer only substitutes
        # placeholders in the raw, so that embed would never be resolved and would
        # be reported as an orphan. Such a link renders natively instead; the
        # nested embed then tokenizes into the raw, where the importer resolves it.
        return interface.render_default(node) unless deferrable_children?(node)

        # A bare URL records no text, so the importer re-emits it bare and
        # autolinking/oneboxing keep working; `presence` catches a blank label the
        # same way (`[](url)` shows nothing).
        text = node.bare? ? nil : interface.render_children(node).presence
        collector.link(url: node.href, text:)
      end
      private_class_method :defer_link

      # Whether the quote carries a source post/topic/user reference that needs
      # remapping. A quote attributed only by a display name has none.
      def self.attributed?(node)
        node.post_number || node.topic_id || node.post_id || node.user_id || node.username
      end
      private_class_method :attributed?

      # Markbridge attribution numbers are unbounded Integers, but the
      # IntermediateDB stores ids as SQLite signed 64-bit integers (binding a
      # bignum raises). At most 18 digits fit. A longer number is a numeric post
      # title or junk, not a real id — drop it and let the remaining attribution
      # carry the quote. The Discourse MarkdownScanner quote detector applies the
      # same 18-digit bound (see markdown_scanner/detectors/quote.rb).
      def self.storable_id(value)
        value if value && value < 10**18
      end
      private_class_method :storable_id

      def self.label_formatting?(node)
        node.instance_of?(Markbridge::AST::Bold) || node.instance_of?(Markbridge::AST::Italic) ||
          node.instance_of?(Markbridge::AST::Strikethrough)
      end
      private_class_method :label_formatting?

      # Whether a link label contains only plain text and the inline formatting
      # Discourse allows inside `[…](url)`. This is the single policy point for
      # what a *deferred* link may carry. Extend this list carefully: a kind
      # qualifies only if it renders inline (no blank lines) and is not deferrable
      # itself. Called on the link node and recursively on formatting nodes, so it
      # checks a parent's children either way.
      def self.deferrable_children?(node)
        node.children.all? { |child| deferrable_label_node?(child) }
      end
      private_class_method :deferrable_children?

      def self.deferrable_label_node?(node)
        case node
        when Markbridge::AST::Text, Markbridge::AST::MarkdownText
          true
        when Markbridge::AST::Code
          # The normalizer already hoisted any multi-line code out of inline
          # containers, so a Code still sitting in a label renders inline (a
          # backtick span) whether or not it carries a language — a language
          # alone never makes it a block. Safe to record.
          true
        else
          label_formatting?(node) && deferrable_children?(node)
        end
      end
      private_class_method :deferrable_label_node?

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
      # rewrite instead of falling back to native rendering. Trade-off: the
      # mention becomes frozen source text instead of being remapped through the
      # user map — acceptable, because Discourse would only render it as plain
      # label text inside a link anyway.
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
      # @param embeds [#upload, #quote, #mention, #link, nil] the embed collector;
      #   when nil the embeds render natively.
      # @param defer [Array<Symbol>] which embed kinds to defer (default
      #   {DEFAULT_DEFER}). Ignored when `embeds` is nil.
      # @return [String] Discourse Markdown.
      def to_markdown(source, embeds: nil, defer: DEFAULT_DEFER)
        renderer = embeds ? deferring_renderer(embeds, defer) : nil
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

      # Building the renderer builds its tag library and the Markbridge Discourse
      # renderer, which dups a tag library internally. That is wasted work once per
      # post, since the collector and defer set stay the same for a worker's whole
      # run (EmbedBuffer#clear lets one buffer serve many posts). So keep the built
      # renderer with its key and rebuild only when the key changes.
      #
      # The cache also ties one MarkdownRenderer to one thread: Markbridge's
      # Discourse renderer keeps an `@interface_cache` for the duration of a render
      # (verified in markbridge-0.3.1, lib/markbridge/renderers/discourse/renderer.rb),
      # so the same renderer must not run in two threads at once. Each worker holds
      # its own MarkdownRenderer.
      def deferring_renderer(collector, defer)
        unless @renderer && @renderer_collector.equal?(collector) && @renderer_defer == defer
          @renderer_collector = collector
          @renderer_defer = defer
          @renderer = build_deferring_renderer(collector, defer)
        end

        @renderer
      end

      def build_deferring_renderer(collector, defer)
        tags =
          Array(defer).to_h do |kind|
            node_class, handler =
              self.class.embed_handlers.fetch(kind) { unknown_defer_kind!(kind) }
            tag =
              Markbridge::Renderers::Discourse::Tag.new do |node, interface|
                handler.call(collector, node, interface)
              end
            [node_class, tag]
          end

        Markbridge.discourse_renderer(tags:)
      end

      def unknown_defer_kind!(kind)
        valid = self.class.embed_handlers.keys.join(", ")
        raise ArgumentError, "Unknown defer kind #{kind.inspect}; expected one of #{valid}"
      end
    end
  end
end
