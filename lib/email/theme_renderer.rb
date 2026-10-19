# frozen_string_literal: true

require "html_to_markdown"

module Email
  class ThemeRenderer
    PLACEHOLDER_PATTERN = /%\{([a-zA-Z0-9_.-]+)\}/

    def initialize(unsubscribe_url: nil, locale: I18n.locale, theme_id: nil, preview_theme: false)
      @unsubscribe_url = unsubscribe_url.presence || "#{Discourse.base_url}/my/preferences"
      @locale = locale
      @theme_id = theme_id
      @preview_theme = preview_theme
    end

    def html_header
      fragment("header")
    end

    def html_footer
      fragment("footer")
    end

    def html(content)
      "#{html_header}#{content}#{html_footer}".html_safe
    end

    def text(content)
      header = text_fragment("header")
      footer = text_fragment("footer")
      return content if header.blank? && footer.blank?

      [header, content, footer].filter_map(&:presence).join("\n\n")
    end

    private

    def enabled?
      SiteSetting.enable_email_theme_header_and_footer || (@preview_theme && @theme_id.present?)
    end

    def fragment(name, escape: true)
      return "" if !enabled? || theme.blank?

      @fields ||=
        ThemeField
          .where(theme_id: theme.id, target_id: Theme.targets[:email])
          .pluck(:name, :value)
          .to_h
      value = @fields[name].to_s
      return "" if value.blank?

      value.gsub(PLACEHOLDER_PATTERN) do
        key = Regexp.last_match(1)
        replacement = key == "unsubscribe_url" ? @unsubscribe_url : translations[key]
        next Regexp.last_match(0) if replacement.nil?

        escape ? ERB::Util.html_escape(replacement.to_s) : replacement.to_s
      end
    end

    def text_fragment(name)
      explicit = fragment("#{name}_text", escape: false)
      return explicit if explicit.present?

      value = fragment(name)
      return if value.blank?

      document = Nokogiri::HTML5.fragment(value)
      document
        .css("header, footer, section, nav, main, article, address, figure, figcaption, hgroup")
        .each { |node| node.name = "div" }
      document
        .css("[href], [src]")
        .each do |node|
          %w[href src].each do |attribute|
            next if (url = node[attribute]).blank?
            node[attribute] = if url.start_with?("//")
              "#{URI(Discourse.base_url).scheme}:#{url}"
            else
              UrlHelper.absolute_without_cdn(url)
            end
          end
        end
      HtmlToMarkdown.new(document.to_html).to_markdown
    end

    def theme
      return @theme if defined?(@theme)

      @theme = @theme_id.present? ? Theme.find_by(id: @theme_id) : Theme.find_default
      @theme = nil if @theme&.component || (@theme && (!@theme.enabled? || !@theme.supported?))
      @theme
    end

    def translations
      @translations ||=
        I18n.with_locale(@locale) do
          theme.translations.to_h { |translation| [translation.key, translation.value] }
        end
    end
  end
end
