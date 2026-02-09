# frozen_string_literal: true

# loaded really early
module Plugin
end

class Plugin::Metadata
  # from config/official_plugins.json
  OFFICIAL_PLUGINS =
    Set.new(JSON.load_file(File.join(Rails.root, "config", "official_plugins.json")))

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
