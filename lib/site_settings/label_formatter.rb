# frozen_string_literal: true

module SiteSettings
  class LabelFormatter
    HUMANIZED_ACRONYMS = %w[
      acl
      ai
      api
      bg
      cdn
      cors
      cta
      dm
      eu
      faq
      fg
      ga
      gb
      gtm
      hd
      http
      https
      iam
      id
      imap
      ip
      jpg
      json
      kb
      mb
      oidc
      pm
      png
      pop3
      s3
      smtp
      svg
      tl
      tl0
      tl1
      tl2
      tl3
      tl4
      tld
      txt
      ui
      url
      ux
    ].freeze

    HUMANIZED_MIXED_CASE = [
      ["adobe analytics", "Adobe Analytics"],
      %w[android Android],
      %w[chinese Chinese],
      %w[discord Discord],
      %w[discourse Discourse],
      ["discourse connect", "Discourse Connect"],
      ["discourse discover", "Discourse Discover"],
      ["discourse narrative bot", "Discourse Narrative Bot"],
      %w[facebook Facebook],
      %w[github GitHub],
      %w[google Google],
      %w[gravatar Gravatar],
      %w[gravatars Gravatars],
      %w[ios iOS],
      %w[japanese Japanese],
      %w[linkedin LinkedIn],
      %w[oauth2 OAuth2],
      %w[opengraph OpenGraph],
      ["powered by discourse", "Powered by Discourse"],
      %w[tiktok TikTok],
      %w[tos ToS],
      %w[twitter Twitter],
      %w[vimeo Vimeo],
      %w[wordpress WordPress],
      %w[youtube YouTube],
    ].freeze

    class << self
      def description(setting)
        I18n.t("site_settings.#{setting}", base_path: Discourse.base_path, default: "")
      end

      def humanized_name(setting)
        name = setting.to_s.gsub("_", " ")

        formatted_name =
          (name[0].upcase + name[1..-1])
            .split(" ")
            .map { |word| HUMANIZED_ACRONYMS.include?(word.downcase) ? word.upcase : word }
            .map do |word|
              if word.end_with?("s")
                singular = word[0...-1].downcase
                HUMANIZED_ACRONYMS.include?(singular) ? singular.upcase + "s" : word
              else
                word
              end
            end
            .join(" ")

        HUMANIZED_MIXED_CASE.each do |key, value|
          formatted_name = formatted_name.gsub(/\b#{key}\b/i, value)
        end

        formatted_name
      end

      def keywords(setting)
        translated_keywords = I18n.t("site_settings.keywords.#{setting}", default: "")
        english_translated_keywords = []

        if I18n.locale != :en
          english_translated_keywords =
            I18n.t("site_settings.keywords.#{setting}", default: "", locale: :en).split("|")
        end

        # TODO (martin) We can remove this workaround of checking if
        # we get an array back once keyword translations in languages other
        # than English have been updated not to use YAML arrays.
        if translated_keywords.is_a?(Array)
          return(
            (
              translated_keywords + [SiteSetting.deprecated_setting_alias(setting)] +
                english_translated_keywords
            ).compact
          )
        end

        translated_keywords
          .split("|")
          .concat([SiteSetting.deprecated_setting_alias(setting)] + english_translated_keywords)
          .compact
      end

      def placeholder(setting)
        if !I18n.t("site_settings.placeholder.#{setting}", default: "").empty?
          I18n.t("site_settings.placeholder.#{setting}")
        elsif SiteIconManager.respond_to?("#{setting}_url")
          SiteIconManager.public_send("#{setting}_url")
        end
      end
    end
  end
end
