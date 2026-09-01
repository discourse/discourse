# frozen_string_literal: true

module DiscourseDev
  class << self
    def config
      @config ||= Config.new
    end

    def settings_file
      File.join(root, "config", "settings.yml")
    end

    def root
      File.expand_path("..", __dir__)
    end
  end
end
