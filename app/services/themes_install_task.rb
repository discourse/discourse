# frozen_string_literal: true

class ThemesInstallTask
  def self.install(yml)
    counts = { installed: 0, updated: 0, skipped: 0, errors: 0 }
    log = []
    themes = YAML::load(yml)
    themes.each do |theme|
      name = theme[0]
      val = theme[1]
      installer = new(val)

      if installer.theme_exists?
        log << "#{name}: is already installed"
        counts[:skipped] += 1
      else
        begin
          installer.install
          log << "#{name}: installed from #{installer.url}"
          counts[:installed] += 1
        rescue RemoteTheme::ImportError, Discourse::InvalidParameters => err
          log << "#{name}: #{err.message}"
          counts[:errors] += 1
        end
      end
    end

    [log, counts]
  end

  attr_reader :url, :options

  def initialize(url_or_options = nil)
    if url_or_options.is_a?(Hash)
      @url = url_or_options.fetch("url")
      @options = url_or_options
    else
      @url = url_or_options
      @options = {}
    end
  end

  def theme_exists?
    RemoteTheme
      .where(remote_url: url)
      .where(branch: options.fetch("branch", nil))
      .exists?
  end

  def install
    theme = RemoteTheme.import_theme(url, Discourse.system_user, private_key: options["private_key"], branch: options["branch"])
    theme.set_default! if options.fetch("default", false)
  end
end
