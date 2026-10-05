# frozen_string_literal: true

module MarkdownEndpoint
  class CookedProcessor
    BLOCK_TAG = "discourse-markdown-block"
    INLINE_TAG = "discourse-markdown-inline"
    VERSION = 5

    class PreservedBlockConverter < ReverseMarkdown::Converters::Base
      def convert(node, _state = {})
        "\n\n#{node.text}\n\n"
      end
    end

    class PreservedInlineConverter < ReverseMarkdown::Converters::Base
      def convert(node, _state = {})
        node.text
      end
    end

    ReverseMarkdown::Converters.register(BLOCK_TAG.to_sym, PreservedBlockConverter.new)
    ReverseMarkdown::Converters.register(INLINE_TAG.to_sym, PreservedInlineConverter.new)

    def self.to_markdown(cooked_html, post_url: nil)
      new(cooked_html, post_url:).to_markdown
    end

    def initialize(cooked_html, post_url: nil)
      @fragment = Nokogiri::HTML5.fragment(cooked_html.to_s)
      @post_url = post_url
    end

    def to_markdown
      strip_chrome
      replace_emojis
      replace_mentions
      replace_hashtags
      replace_lightboxes
      replace_code_blocks
      replace_footnotes
      replace_quotes
      replace_oneboxes
      replace_details
      replace_polls
      replace_events
      absolutize_urls

      ReverseMarkdown.convert(@fragment.to_html, github_flavored: true, unknown_tags: :bypass).strip
    end

    private

    def strip_chrome
      @fragment.css("div.meta, div.quote-controls").each(&:remove)
    end

    def replace_emojis
      @fragment
        .css("img.emoji")
        .each do |image|
          shortcode = image["title"] || image["alt"] || ""
          image.replace(preserved_inline(EmojiConverter.convert(shortcode)))
        end
    end

    def replace_mentions
      @fragment
        .css("a.mention")
        .each do |anchor|
          anchor.replace(preserved_inline("@#{anchor.text.to_s.delete_prefix("@").strip}"))
        end
    end

    def replace_hashtags
      @fragment
        .css("a.hashtag, a.hashtag-cooked")
        .each do |anchor|
          anchor.replace(preserved_inline("##{anchor.text.to_s.delete_prefix("#").strip}"))
        end
    end

    def replace_lightboxes
      @fragment
        .css("a.lightbox")
        .each do |anchor|
          image = anchor.at_css("img")
          if image
            image["src"] = anchor["href"] if anchor["href"].present?
            anchor.replace(image)
          else
            anchor.remove
          end
        end

      @fragment
        .css("div.lightbox-wrapper")
        .each do |wrapper|
          content = wrapper.at_css("img, picture")
          content ? wrapper.replace(content) : wrapper.remove
        end
    end

    def replace_code_blocks
      @fragment
        .css("pre > code")
        .each do |code|
          language = code["class"].to_s.split.find { |name| name.match?(/\A(?:lang|language)-/) }
          language = language&.sub(/\A(?:lang|language)-/, "")
          content = code.text
          longest_run = content.scan(/`+/).map(&:length).max.to_i
          fence = "`" * [3, longest_run + 1].max
          opening = language.present? ? "#{fence}#{language}" : fence
          code.parent.replace(preserved_block("#{opening}\n#{content}\n#{fence}"))
        end
    end

    def replace_footnotes
      @fragment.css("a.footnote-backref").each(&:remove)
      @fragment
        .css("sup.footnote-ref a")
        .each { |anchor| anchor.replace(preserved_inline(escape_text(anchor.text))) }
    end

    def replace_quotes
      @fragment
        .css("aside.quote")
        .each do |quote|
          attribution = quote.at_css(".title a")
          username =
            attribution&.text&.strip&.delete_suffix(":").presence || quote["data-username"].to_s
          url = absolute_url(attribution&.[]("href") || "#")
          body = convert_html(quote.at_css("blockquote")&.inner_html)
          lines = ["> [@#{escape_text(username)}](#{url}):", ">"]
          body.each_line { |line| lines << "> #{line.chomp}" }
          quote.replace(preserved_block(lines.join("\n")))
        end
    end

    def replace_oneboxes
      @fragment
        .css("aside.onebox")
        .each do |onebox|
          title_link = onebox.at_css("h3 a")
          title = title_link&.text&.strip
          url =
            title_link&.[]("href") || onebox.at_css("header.source a")&.[]("href") ||
              onebox.at_css("article a")&.[]("href")
          excerpt_node = onebox.at_css("article.onebox-body p, .onebox-body p")
          excerpt =
            if excerpt_node
              excerpt_node = excerpt_node.dup
              excerpt_node.css("br").each { |line_break| line_break.replace("\n") }
              excerpt_node.text.strip
            end
          lines = []
          if url.present? && title.present?
            lines << "> **[#{escape_text(title)}](#{absolute_url(url)})**"
          elsif url.present?
            lines << "> <#{absolute_url(url)}>"
          end
          if excerpt.present?
            lines << ">"
            excerpt.each_line { |line| lines << "> #{escape_text(line.chomp)}" }
          end
          lines.empty? ? onebox.remove : onebox.replace(preserved_block(lines.join("\n")))
        end
    end

    def replace_details
      @fragment
        .css("details")
        .each do |details|
          summary = escape_text(details.at_css("summary")&.text&.strip.to_s)
          body_html = details.children.reject { |node| node.name == "summary" }.map(&:to_html).join
          body = convert_html(body_html)
          lines = ["> **#{summary}**", ">"]
          body.each_line { |line| lines << "> #{line.chomp}" }
          details.replace(preserved_block(lines.join("\n")))
        end
    end

    def replace_polls
      @fragment
        .css("div.poll")
        .each do |poll|
          title =
            poll["data-poll-title"].presence ||
              poll.at_css("[data-poll-title]")&.[]("data-poll-title").presence
          label = title.present? ? "Poll: #{escape_text(title)}" : "Poll"
          label += " ([view on site](#{absolute_url(@post_url)}))" if @post_url.present?
          poll.replace(preserved_block("_#{label}_"))
        end
    end

    def replace_events
      @fragment
        .css("div.discourse-post-event")
        .each do |event|
          name = event["data-name"].presence || I18n.t("markdown_endpoints.event.name")
          sections = ["**#{escape_text(EmojiConverter.convert(name))}**"]
          fields = []
          %w[start end].each do |attribute|
            next if event["data-#{attribute}"].blank?

            value = event_date(event["data-#{attribute}"], event)
            fields << "**#{I18n.t("markdown_endpoints.event.#{attribute}")}:** #{escape_text(value)}"
          end
          if event["data-location"].present?
            location = CGI.unescapeHTML(event["data-location"])
            fields << "**#{I18n.t("markdown_endpoints.event.location")}:** #{escape_text(location)}"
          end
          if event["data-url"].present?
            url = event["data-url"].strip
            url = "https://#{url}" unless url.match?(%r{\A(?:[a-z][a-z0-9+.-]*:|/)}i)
            if url.match?(%r{\A(?:https?://|/)}i)
              url = URI::DEFAULT_PARSER.escape(absolute_url(url), /[\s<>"()\\]/)
              fields << "**#{I18n.t("markdown_endpoints.event.link")}:** <#{url}>"
            end
          end
          sections << fields.join("\\\n") if fields.present?
          body = convert_html(event.inner_html)
          sections << body if body.present?
          content = sections.join("\n\n").lines.map { |line| "> #{line.chomp}".rstrip }.join("\n")
          event.replace(preserved_block(content))
        end
    end

    def event_date(value, event)
      all_day = event["data-all-day"] == "true"
      format = all_day ? :date_only : :long
      formatted =
        begin
          I18n.l(DateTime.parse(value), format:)
        rescue ArgumentError
          value
        end
      return formatted if all_day

      I18n.t(
        "markdown_endpoints.event.date_with_timezone",
        date: formatted,
        timezone: event["data-timezone"].presence || "UTC",
      )
    end

    def absolutize_urls
      @fragment
        .css("[href], [src]")
        .each do |node|
          node["href"] = absolute_url(node["href"]) if node["href"].present?
          node["src"] = absolute_url(node["src"], cdn: true) if node["src"].present?
        end
    end

    def absolute_url(url, cdn: false)
      return url if url.blank? || url.start_with?("#", "mailto:", "data:")
      return "#{Discourse.base_url.split(":", 2).first}:#{url}" if url.start_with?("//")
      return url if url.match?(/\A[a-z][a-z0-9+.-]*:/i)
      return UrlHelper.absolute(url, cdn ? Discourse.asset_host : nil) if url.start_with?("/")

      "#{Discourse.base_url}/#{url}"
    end

    def convert_html(html)
      fragment = self.class.new(html, post_url: @post_url)
      fragment.to_markdown
    end

    def escape_text(text)
      text
        .to_s
        .gsub(/[\\`*_\[\]<>]/) { |character| "\\#{character}" }
        .sub(/\A[#>-]/) { |character| "\\#{character}" }
    end

    def preserved_inline(content)
      node = Nokogiri::XML::Node.new(INLINE_TAG, @fragment.document)
      node.content = content
      node
    end

    def preserved_block(content)
      node = Nokogiri::XML::Node.new(BLOCK_TAG, @fragment.document)
      node.content = content
      node
    end
  end
end
