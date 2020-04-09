# frozen_string_literal: true

class ThemesInstallTask
  def self.install(themes)
    counts = { installed: 0, updated: 0, errors: 0 }
    log = []
    themes.each do |name, val|
      installer = new(val)

      if installer.theme_exists?
        installer.update
        log << "#{name}: is already installed. Updating from remote."
        counts[:updated] += 1
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

  attr_reader :url

  def initialize(url_or_options = nil)
    if url_or_options.is_a?(Hash)
      @url = url_or_options.fetch("url")
      @options = url_or_options
    else
      @url = url_or_options
      @options = {}
    end
    find_existing
  end

  def theme_exists?
    @theme.present?
  end

  def find_existing
    @remote_theme = RemoteTheme.find_by(remote_url: @url, branch: @options.fetch("branch", nil))
    @theme = @remote_theme&.theme
  end

  def install
    @theme = RemoteTheme.import_theme(@url, Discourse.system_user, private_key: @options["private_key"], branch: @options["branch"])
    @theme.set_default! if @options.fetch("default", false)
    add_component_to_all_themes
  end

  def update
    @remote_theme.update_from_remote
    add_component_to_all_themes
  end

  def add_component_to_all_themes
    return if (!@options.fetch("install_to_all_themes", false) || !@theme.component)

    Theme.where(component: false).each do |parent_theme|
      next if ChildTheme.where(parent_theme_id: parent_theme.id, child_theme_id: @theme.id).exists?
      parent_theme.add_relative_theme!(:child, @theme)
    end
  end
end
