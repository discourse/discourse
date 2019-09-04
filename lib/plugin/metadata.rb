# frozen_string_literal: true

# loaded really early
module Plugin; end

class Plugin::Metadata

  OFFICIAL_PLUGINS ||= Set.new([
    # TODO: Remove this after everyone upgraded `discourse-canned-replies`
    # to the renamed version.
    "Canned Replies",
    "customer-flair",
    "discourse-adplugin",
    "discourse-affiliate",
    "discourse-akismet",
    "discourse-assign",
    "discourse-auto-deactivate",
    "discourse-backup-uploads-to-s3",
    "discourse-bbcode",
    "discourse-bbcode-color",
    "discourse-cakeday",
    "discourse-canned-replies",
    "discourse-calendar",
    "discourse-characters-required",
    "discourse-chat-integration",
    "discourse-checklist",
    "discourse-code-review",
    "discourse-crowd",
    "discourse-data-explorer",
    "discourse-details",
    "discourse-encrypt",
    "discourse-footnote",
    "discourse-github",
    "discourse-gradle-issue",
    "discourse-graphviz",
    "discourse-invite-tokens",
    "discourse-local-dates",
    "discourse-logster-rate-limit-checker",
    "discourse-logster-transporter",
    "discourse-math",
    "discourse-moderator-attention",
    "discourse-narrative-bot",
    "discourse-nginx-performance-report",
    "discourse-no-bump",
    "discourse-oauth2-basic",
    "discourse-patreon",
    "discourse-perspective",
    "discourse-plugin-discord-auth",
    "discourse-plugin-linkedin-auth",
    "discourse-plugin-office365-auth",
    "discourse-steam-login",
    "discourse-login-with-amazon",
    "discourse-policy",
    "discourse-presence",
    "discourse-prometheus",
    "discourse-prometheus-alert-receiver",
    "discourse-push-notifications",
    "discourse-saved-searches",
    "discourse-signatures",
    "discourse-sitemap",
    "discourse-solved",
    "discourse-spoiler-alert",
    "discourse-user-notes",
    "discourse-styleguide",
    "discourse-tooltips",
    "discourse-translator",
    "discourse-user-card-badges",
    "discourse-voting",
    "discourse-yearly-review",
    "discourse-openid-connect",
    "docker_manager",
    "lazy-yt",
    "poll"
  ])

  FIELDS ||= [:name, :about, :version, :authors, :url, :required_version]
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
