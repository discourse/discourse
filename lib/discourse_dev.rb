# frozen_string_literal: true

module DiscourseDev
  def self.config
    @config ||= Config.new
  end

  def self.settings_file
    File.join(root, "config", "settings.yml")
  end

  def self.root
    File.expand_path("..", __dir__)
  end
end
