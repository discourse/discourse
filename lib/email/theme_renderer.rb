# frozen_string_literal: true

require "html_to_markdown"

module Email
  class ThemeRenderer
    PLACEHOLDER_PATTERN = /%\{([a-zA-Z0-9_.-]+)\}/

    def initialize(unsubscribe_url: nil, locale: I18n.locale)
      @unsubscribe_url = unsubscribe_url.presence || "#{Discourse.base_url}/my/preferences"
      @locale = locale
    end

    def html_header
      fragment(:email_header)
    end

    def html_footer
      fragment(:email_footer)
    end

    def html(content)
      "#{html_header}#{content}#{html_footer}".html_safe
    end

    def text(content)
      [text_fragment(:email_header), content, text_fragment(:email_footer)].filter_map(
        &:presence
      ).join("\n\n")
    end

    private

    def fragment(target)
      return "" if !SiteSetting.enable_email_theme_header_and_footer

      themes
        .filter_map do |source_theme|
          value =
            Theme.lookup_field(source_theme.id, target, target.to_s, skip_transformation: true)
          next if value.blank?

          source_translations = translations(source_theme)
          value.gsub(PLACEHOLDER_PATTERN) do
            key = Regexp.last_match(1)

            if key == "unsubscribe_url"
              @unsubscribe_url
            elsif source_translations.key?(key)
              source_translations[key]
            else
              Regexp.last_match(0)
            end
          end
        end
        .join("\n")
    end

    def text_fragment(target)
      value = fragment(target)
      HtmlToMarkdown.new(value).to_markdown if value.present?
    end

    def theme
      return @theme if defined?(@theme)

      @theme = Theme.find_default
    end

    def themes
      return @themes if defined?(@themes)
      return @themes = [] if theme.blank?

      theme_ids = Theme.transform_ids(theme.id)
      themes_by_id =
        I18n.with_locale(@locale) do
          Theme.where(id: theme_ids).includes(:locale_fields).index_by(&:id)
        end
      @themes = theme_ids.filter_map { |theme_id| themes_by_id[theme_id] }
    end

    def translations(source_theme)
      @translations ||= {}
      @translations[source_theme.id] ||= I18n.with_locale(@locale) do
        source_theme.translations.to_h { |translation| [translation.key, translation.value] }
      end
    end
  end
end
