# frozen_string_literal: true

# loaded really early
module Plugin
end

class Plugin::Metadata
  # from config/official_plugins.json
  OFFICIAL_PLUGINS = Set.new(JSON.load_file(Rails.root.join("config/official_plugins.json").to_s))

  FIELDS = %i[
    name
    about
    version
    authors
    contact_emails
    url
    required_version
    meta_topic_id
    label
    gemfile
  ]
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

  # `# gemfile: true` resolves the Gemfile next to plugin.rb together with
  # those of the other plugins and the application's bundle, before any
  # plugin.rb runs; see PluginGem.activate_gemfiles. Gems are activated, not
  # required, so `require:` options have no effect. The plugin's
  # Gemfile.lock, if any, pins its direct dependencies to the locked versions
  # (the highest any plugin locks wins); if they can't be resolved together
  # they are dropped with a note.
  def gemfile=(value)
    @gemfile = value == "true"
  end

  def self.parse(text)
    metadata = new
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
        public_send("#{attribute}=", value.strip.truncate(MAX_FIELD_LENGTHS[attribute] || 1000))
      end
    end

    true
  end
end
