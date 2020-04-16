# frozen_string_literal: true

class ThemesInstallTask
  def self.install(themes)
    counts = { installed: 0, updated: 0, errors: 0 }
    log = []
    themes.each do |name, val|
      installer = new(val)
      next if installer.url.nil?

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

  attr_reader :url, :options

  def initialize(url_or_options = nil)
    if url_or_options.is_a?(Hash)
      url_or_options.deep_symbolize_keys!
      @url = url_or_options.fetch(:url, nil)
      @options = url_or_options
    else
      @url = url_or_options
      @options = {}
    end
  end

  def repo_name
    @url.gsub(Regexp.union('git@github.com:', 'https://github.com/', '.git'), '')
  end

  def theme_exists?
    @remote_theme = RemoteTheme
      .where("remote_url like ?", "%#{repo_name}%")
      .where(branch: @options.fetch(:branch, nil))
      .first
    @theme = @remote_theme&.theme
    @theme.present?
  end

  def install
    @theme = RemoteTheme.import_theme(@url, Discourse.system_user, private_key: @options[:private_key], branch: @options[:branch])
    @theme.set_default! if @options.fetch(:default, false)
    add_component_to_all_themes
  end

  def update
    @remote_theme.update_from_remote
    add_component_to_all_themes
  end

  def add_component_to_all_themes
    return if (!@options.fetch(:add_to_all_themes, false) || !@theme.component)

    Theme.where(component: false).each do |parent_theme|
      next if ChildTheme.where(parent_theme_id: parent_theme.id, child_theme_id: @theme.id).exists?
      parent_theme.add_relative_theme!(:child, @theme)
    end
  end
end
