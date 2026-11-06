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

  # `# gemfile: true` in plugin.rb makes the plugin declare its gems in a
  # Gemfile next to plugin.rb instead of calling `gem` in plugin.rb. See
  # PluginGem.activate_gemfiles for the implementation. The rules:
  # - The Gemfiles of all opted-in plugins are resolved together with the
  #   application's bundle, before any plugin.rb runs.
  # - The gems are activated, not required. `require:` options have no
  #   effect; the plugin requires its gems itself.
  # - A Gemfile.lock with a CHECKSUMS section must be committed next to the
  #   Gemfile (`bundle lock --add-checksums`).
  # - A gem the application has keeps the application's version. For other
  #   gems the highest version locked by any plugin is used.
  # - Every resolved gem must match a committed lock in version, platform
  #   and source, and a downloaded gem must match the locked SHA256
  #   checksum. Otherwise the boot fails.
  # - Gems must come from the application's gem servers or from a path with
  #   a gemspec. Git gems are refused.
  # - Gemfiles and gemspecs are evaluated on every boot. Installed gems are
  #   reused.
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
