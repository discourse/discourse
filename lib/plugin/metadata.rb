# loaded really early
module Plugin; end

class Plugin::Metadata

  OFFICIAL_PLUGINS ||= Set.new([
    "customer-flair",
    "discourse-adplugin",
    "discourse-akismet",
    "discourse-backup-uploads-to-s3",
    "discourse-cakeday",
    "Canned Replies",
    "discourse-data-explorer",
    "discourse-details",
    "discourse-nginx-performance-report",
    "discourse-push-notifications",
    "discourse-chat-integration",
    "discourse-solved",
    "Spoiler Alert!",
    "staff-notes",
    "GitHub badges",
    "lazyYT",
    "logster-rate-limit-checker",
    "poll",
    "discourse-plugin-linkedin-auth",
    "discourse-plugin-office365-auth",
    "discourse-oauth2-basic",
    "discourse-math",
    "discourse-bbcode-color",
    "discourse-bbcode",
    "discourse-affiliate",
    "discourse-translator",
    "discourse-patreon",
    "discourse-prometheus",
    "discourse-assign",
    "discourse-narrative-bot",
    "discourse-presence",
    "discourse-staff-notes",
    "discourse-voting",
    "docker_manager",
    "discourse-signatures",
    "discourse-local-dates",
    "discourse-crowd",
    "discourse-footnote",
    "discourse-gradle-issue",
    "discourse-no-bump",
    "discourse-moderator-attention",
    "discourse-sitemap",
    "discourse-tooltips",
    "discourse-styleguide",
    "discourse-saved-searches",
    "discourse-user-card-badges",
    "discourse-policy",
    "discourse-github-linkback",
    "discourse-characters-required",
    "discourse-auto-deactivate",
    "discourse-invite-tokens"
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
