# frozen_string_literal: true

# loaded really early
module Plugin; end

class Plugin::Metadata

  OFFICIAL_PLUGINS ||= Set.new([
    # TODO: Remove this after everyone upgraded `discourse-canned-replies`
    # to the renamed version.
    "Canned Replies",
    "discourse-adplugin",
    "discourse-affiliate",
    "discourse-akismet",
    "discourse-algolia",
    "discourse-apple-auth",
    "discourse-assign",
    "discourse-auto-deactivate",
    "discourse-bbcode",
    "discourse-bbcode-color",
    "discourse-cakeday",
    "discourse-calendar",
    "discourse-canned-replies",
    "discourse-categories-suppressed",
    "discourse-category-experts",
    "discourse-characters-required",
    "discourse-chat-integration",
    "discourse-checklist",
    "discourse-code-review",
    "discourse-crowd",
    "discourse-data-explorer",
    "discourse-details",
    "discourse-docs",
    "discourse-encrypt",
    "discourse-fontawesome-pro",
    "discourse-footnote",
    "discourse-github",
    "discourse-gradle-issue",
    "discourse-graphviz",
    "discourse-invite-tokens",
    "discourse-local-dates",
    "discourse-login-with-amazon",
    "discourse-logster-rate-limit-checker",
    "discourse-logster-transporter",
    "discourse-lti",
    "discourse-math",
    "discourse-moderator-attention",
    "discourse-narrative-bot",
    "discourse-nginx-performance-report",
    "discourse-no-bump",
    "discourse-oauth2-basic",
    "discourse-openid-connect",
    "discourse-patreon",
    "discourse-perspective-api",
    "discourse-linkedin-auth",
    "discourse-microsoft-auth",
    "discourse-policy",
    "discourse-presence",
    "discourse-prometheus",
    "discourse-prometheus-alert-receiver",
    "discourse-push-notifications",
    "discourse-reactions",
    "discourse-restricted-replies",
    "discourse-rss-polling",
    "discourse-saml",
    "discourse-saved-searches",
    "discourse-shared-edits",
    "discourse-signatures",
    "discourse-sitemap",
    "discourse-solved",
    "discourse-spoiler-alert",
    "discourse-staff-alias",
    "discourse-steam-login",
    "discourse-subscriptions",
    "discourse-teambuild",
    "discourse-tooltips",
    "discourse-translator",
    "discourse-user-card-badges",
    "discourse-user-notes",
    "discourse-vk-auth",
    "discourse-voting",
    "discourse-yearly-review",
    "discourse-zendesk-plugin",
    "docker_manager",
    "lazy-yt",
    "poll",
    "styleguide",
  ])

  FIELDS ||= [:name, :about, :version, :authors, :contact_emails, :url, :required_version, :transpile_js]
  attr_accessor(*FIELDS)

  def self.parse(text)
    metadata = self.new
    text.each_line do |line|
      break unless metadata.parse_line(line)
    end
    metadata
  end

  def official?
    OFFICIAL_PLUGINS.include?(name)
  end

  def parse_line(line)
    line = line.strip

    unless line.empty?
      return false unless line[0] == "#"
      attribute, *description = line[1..-1].split(":")

      description = description.join(":")
      attribute = attribute.strip.gsub(/ /, '_').to_sym

      if FIELDS.include?(attribute)
        self.public_send("#{attribute}=", description.strip)
      end
    end

    true
  end
end
