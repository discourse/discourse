# frozen_string_literal: true

module SiteSettings
  class LabelFormatter
    HUMANIZED_ACRONYMS =
      Set.new(
        %w[
          2fa
          acl
          ai
          api
          arn
          aws
          bg
          cdn
          cors
          csp
          csrf
          css
          cta
          csv
          cx
          db
          dm
          dns
          eu
          faq
          fg
          ga
          gb
          gpu
          gpt
          gtm
          hd
          html
          http
          https
          iam
          id
          imap
          ip
          jpg
          json
          kb
          llm
          mb
          mfa
          oauth
          oidc
          pdf
          pm
          png
          pop3
          rest
          rss
          s3
          saml
          smtp
          sso
          svg
          tei
          tl
          tl0
          tl1
          tl2
          tl3
          tl4
          tld
          totp
          txt
          ui
          url
          ux
          vpc
          xml
          yaml
          yml
        ],
      ).freeze

    HUMANIZED_MIXED_CASE = [
      %w[apple Apple],
      ["adobe analytics", "Adobe Analytics"],
      ["amazon web services", "Amazon Web Services"],
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
      ["google analytics", "Google Analytics"],
      ["google tag manager", "Google Tag Manager"],
      %w[gravatar Gravatar],
      %w[gravatars Gravatars],
      %w[gitter Gitter],
      %w[ios iOS],
      %w[japanese Japanese],
      %w[linkedin LinkedIn],
      %w[meta Meta],
      %w[mediaconvert MediaConvert],
      %w[microsoft Microsoft],
      %w[matrix Matrix],
      %w[mattermost Mattermost],
      %w[oauth2 OAuth2],
      ["openid connect", "OpenID Connect"],
      %w[openai OpenAI],
      %w[opengraph OpenGraph],
      ["powered by discourse", "Powered by Discourse"],
      %w[tiktok TikTok],
      %w[tos ToS],
      %w[twitter Twitter],
      %w[telegram Telegram],
      %w[teams Teams],
      %w[rocketchat RocketChat],
      %w[slack Slack],
      %w[vimeo Vimeo],
      %w[wordpress WordPress],
      %w[webex WebEx],
      %w[youtube YouTube],
      %w[zulip Zulip],
    ].freeze

    HUMANIZED_MIXED_CASE_REGEX =
      HUMANIZED_MIXED_CASE.map { |key, value| [/\b#{Regexp.escape(key)}\b/i, value] }.freeze

    class << self
      def description(setting)
        I18n.t("site_settings.#{setting}", base_path: Discourse.base_path, default: "")
      end

      def humanized_name(setting)
        name = setting.to_s.tr("_", " ")
        words = name.split(" ")

        words[0] = words[0].capitalize

        words.map! do |word|
          word_downcase = word.downcase

          if HUMANIZED_ACRONYMS.include?(word_downcase)
            word.upcase
          elsif word.end_with?("s") && HUMANIZED_ACRONYMS.include?(word_downcase[0...-1])
            word_downcase[0...-1].upcase + "s"
          else
            word
          end
        end

        result = words.join(" ")

        HUMANIZED_MIXED_CASE_REGEX.each do |regex, replacement|
          result = result.gsub(regex, replacement)
        end

        result
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
