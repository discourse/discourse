# loaded really early
module Plugin; end

class Plugin::Metadata

  OFFICIAL_PLUGINS ||= Set.new([
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
    "discourse-characters-required",
    "discourse-chat-integration",
    "discourse-checklist",
    "discourse-crowd",
    "discourse-data-explorer",
    "discourse-details",
    "discourse-etiquette",
    "discourse-footnote",
    "discourse-github-linkback",
    "discourse-gradle-issue",
    "discourse-invite-tokens",
    "discourse-local-dates",
    "discourse-math",
    "discourse-moderator-attention",
    "discourse-narrative-bot",
    "discourse-nginx-performance-report",
    "discourse-no-bump",
    "discourse-oauth2-basic",
    "discourse-patreon",
    "discourse-plugin-discord-auth",
    "discourse-plugin-linkedin-auth",
    "discourse-plugin-office365-auth",
    "discourse-policy",
    "discourse-presence",
    "discourse-prometheus",
    "discourse-push-notifications",
    "discourse-saved-searches",
    "discourse-signatures",
    "discourse-sitemap",
    "discourse-solved",
    "discourse-staff-notes",
    "discourse-styleguide",
    "discourse-tooltips",
    "discourse-translator",
    "discourse-user-card-badges",
    "discourse-voting",
    "docker_manager",
    "GitHub badges",
    "lazyYT",
    "logster-rate-limit-checker",
    "poll",
    "Spoiler Alert!",
    "staff-notes"
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
        self.send("#{attribute}=", description.strip)
      end
    end

    true
  end
end
