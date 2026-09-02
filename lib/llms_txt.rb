# frozen_string_literal: true

module LlmsTxt
  MCP_SETUP_URL =
    "https://github.com/discourse/discourse-mcp#quick-start-release"

  def self.generate
    I18n.with_locale(SiteSetting.default_locale) do
      title = one_line(SiteSetting.title).presence || Discourse.current_hostname
      parts = ["# #{title}"]

      description =
        one_line(SiteSetting.site_description).presence ||
          one_line(SiteSetting.short_site_description).presence
      parts << "> #{description}" if description
      parts << translated_text("human_community_policy")
      parts << translated_text("account_required") if SiteSetting.login_required
      parts << translated_text("crawler_policy")
      parts << one_line(
        I18n.t("llms_txt.mcp_guidance", base_url: Discourse.base_url)
      )
      parts << section(
        translated_text("sections.preferred_interface"),
        [translated_link(:mcp, MCP_SETUP_URL)]
      )

      if !SiteSetting.login_required
        public_links = [
          translated_local_link(:search, "/search"),
          translated_local_link(:filter, "/filter"),
          translated_local_link(:latest, "/latest"),
          translated_local_link(:categories, "/categories")
        ]
        if SiteSetting.enable_sitemap
          public_links << translated_local_link(:sitemap, "/sitemap.xml")
        end
        parts << section(
          translated_text("sections.public_web_access"),
          public_links
        )
      end

      optional_links = []
      if !SiteSetting.login_required
        optional_links << translated_local_link(:about, "/about")
        optional_links << translated_local_link(:guidelines, "/guidelines")
      end
      optional_links << translated_local_link(:tos, "/tos")
      optional_links << translated_local_link(:privacy, "/privacy")
      if optional_links.present?
        parts << section(translated_text("sections.optional"), optional_links)
      end

      "#{parts.join("\n\n")}\n"
    end
  end

  def self.one_line(value)
    value.to_s.gsub(/[[:space:]]+/, " ").strip
  end
  private_class_method :one_line

  def self.section(heading, links)
    "## #{heading}\n\n#{links.join("\n")}"
  end
  private_class_method :section

  def self.translated_link(key, target)
    label = translated_text("links.#{key}.label")
    note = translated_text("links.#{key}.note")
    "- [#{label}](#{target}): #{note}"
  end
  private_class_method :translated_link

  def self.translated_local_link(key, route)
    translated_link(key, "#{Discourse.base_path}#{route}")
  end
  private_class_method :translated_local_link

  def self.translated_text(key)
    one_line(I18n.t("llms_txt.#{key}"))
  end
  private_class_method :translated_text
end
