# frozen_string_literal: true

# loaded really early
module Plugin
end

class Plugin::Metadata
  OFFICIAL_PLUGINS =
    Set.new(
      %w[
        discourse-adplugin
        discourse-affiliate
        discourse-ai
        discourse-akismet
        discourse-algolia
        discourse-apple-auth
        discourse-assign
        discourse-auto-deactivate
        discourse-bbcode
        discourse-bbcode-color
        discourse-cakeday
        discourse-calendar
        discourse-categories-suppressed
        discourse-category-experts
        discourse-characters-required
        discourse-chat-integration
        discourse-code-review
        discourse-crowd
        discourse-data-explorer
        discourse-details
        discourse-docs
        discourse-follow
        discourse-fontawesome-pro
        discourse-gamification
        discourse-geoblocking
        discourse-github
        discourse-gradle-issue
        discourse-graphviz
        discourse-group-tracker
        discourse-hcaptcha
        discourse-invite-tokens
        discourse-jira
        discourse-lazy-videos
        discourse-local-dates
        discourse-login-with-amazon
        discourse-logster-rate-limit-checker
        discourse-logster-transporter
        discourse-lti
        discourse-math
        discourse-microsoft-auth
        discourse-narrative-bot
        discourse-newsletter-integration
        discourse-no-bump
        discourse-oauth2-basic
        discourse-openid-connect
        discourse-patreon
        discourse-perspective-api
        discourse-policy
        discourse-post-voting
        discourse-presence
        discourse-prometheus
        discourse-prometheus-alert-receiver
        discourse-push-notifications
        discourse-reactions
        discourse-restricted-replies
        discourse-rss-polling
        discourse-salesforce
        discourse-saml
        discourse-saved-searches
        discourse-signatures
        discourse-solved
        discourse-staff-alias
        discourse-steam-login
        discourse-subscriptions
        discourse-tag-by-group
        discourse-teambuild
        discourse-templates
        discourse-tooltips
        discourse-topic-voting
        discourse-translator
        discourse-user-card-badges
        discourse-user-notes
        discourse-vk-auth
        discourse-whos-online
        discourse-yearly-review
        discourse-zendesk-plugin
        discourse-zoom
        automation
        chat
        checklist
        docker_manager
        footnote
        poll
        spoiler-alert
        styleguide
      ],
    )

  FIELDS = %i[name about version authors contact_emails url required_version meta_topic_id label]
  attr_accessor(*FIELDS)

  MAX_FIELD_LENGTHS = {
    name: 75,
    about: 350,
    authors: 200,
    contact_emails: 200,
    url: 500,
    label: 20,
  }

  def meta_topic_id=(value)
    @meta_topic_id =
      begin
        Integer(value)
      rescue StandardError
        nil
      end
  end

  def self.parse(text)
    metadata = self.new
    text.each_line { |line| break unless metadata.parse_line(line) }
    metadata
  end

  def official?
    OFFICIAL_PLUGINS.include?(name)
  end

  def parse_line(line)
    line = line.strip

    unless line.empty?
      return false unless line[0] == "#"
      attribute, *value = line[1..-1].split(":")

      value = value.join(":")
      attribute = attribute.strip.gsub(/ /, "_").to_sym

      if FIELDS.include?(attribute)
        self.public_send(
          "#{attribute}=",
          value.strip.truncate(MAX_FIELD_LENGTHS[attribute] || 1000),
        )
      end
    end

    true
  end
end
