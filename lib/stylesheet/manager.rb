# frozen_string_literal: true

require_dependency 'distributed_cache'
require_dependency 'stylesheet/compiler'

module Stylesheet; end

class Stylesheet::Manager

  CACHE_PATH ||= 'tmp/stylesheet-cache'
  MANIFEST_DIR ||= "#{Rails.root}/tmp/cache/assets/#{Rails.env}"
  MANIFEST_FULL_PATH ||= "#{MANIFEST_DIR}/stylesheet-manifest"
  THEME_REGEX ||= /_theme$/
  COLOR_SCHEME_STYLESHEET ||= "color_definitions"

  @@lock = Mutex.new

  def self.cache
    @cache ||= DistributedCache.new("discourse_stylesheet")
  end

  def self.clear_theme_cache!
    cache.hash.keys.select { |k| k =~ /theme/ }.each { |k| cache.delete(k) }
  end

  def self.clear_color_scheme_cache!
    cache.hash.keys.select { |k| k =~ /color_definitions/ }.each { |k| cache.delete(k) }
  end

  def self.clear_core_cache!(targets)
    cache.hash.keys.select { |k| k =~ /#{targets.join('|')}/ }.each { |k| cache.delete(k) }
  end

  def self.clear_plugin_cache!(plugin)
    cache.hash.keys.select { |k| k =~ /#{plugin}/ }.each { |k| cache.delete(k) }
  end

  def self.color_scheme_cache_key(color_scheme, theme_id = nil)
    color_scheme_name = Slug.for(color_scheme.name) + color_scheme&.id.to_s
    theme_string = theme_id ? "_theme#{theme_id}" : ""
    "#{COLOR_SCHEME_STYLESHEET}_#{color_scheme_name}_#{theme_string}_#{Discourse.current_hostname}"
  end

  def self.precompile_css
    targets = [:desktop, :mobile, :desktop_rtl, :mobile_rtl, :admin, :wizard]
    targets += Discourse.find_plugin_css_assets(include_disabled: true, mobile_view: true, desktop_view: true)

    targets.each do |target|
      $stderr.puts "precompile target: #{target}"

      Stylesheet::Manager::Builder.new(target: target, manager: nil).compile(force: true)
    end
  end

  def self.precompile_theme_css
    themes = Theme.where('user_selectable OR id = ?', SiteSetting.default_theme_id).pluck(:id, :color_scheme_id)

    color_schemes = ColorScheme.where(user_selectable: true).to_a
    color_schemes << ColorScheme.find_by(id: SiteSetting.default_dark_mode_color_scheme_id)
    color_schemes << ColorScheme.base
    color_schemes = color_schemes.compact.uniq

    targets = [:desktop_theme, :mobile_theme]
    compiled = Set.new

    themes.each do |theme_id, color_scheme_id|
      manager = self.new(theme_id: theme_id)

      targets.each do |target|
        next if theme_id == -1

        scss_checker = ScssChecker.new(target, manager.theme_ids)

        manager.load_themes(manager.theme_ids).each do |theme|
          next if compiled.include?("#{target}_#{theme.id}")

          builder = Stylesheet::Manager::Builder.new(
            target: target, theme: theme, manager: manager
          )

          next if theme.component && !scss_checker.has_scss(theme.id)
          $stderr.puts "precompile target: #{target} #{theme.name}"
          builder.compile(force: true)
          compiled << "#{target}_#{theme.id}"
        end
      end

      theme_color_scheme = ColorScheme.find_by_id(color_scheme_id)
      theme = manager.get_theme(theme_id)

      [theme_color_scheme, *color_schemes].compact.uniq.each do |scheme|
        $stderr.puts "precompile target: #{COLOR_SCHEME_STYLESHEET} #{theme.name} (#{scheme.name})"

        Stylesheet::Manager::Builder.new(
          target: COLOR_SCHEME_STYLESHEET,
          theme: theme,
          color_scheme: scheme,
          manager: manager
        ).compile(force: true)
      end

      clear_color_scheme_cache!
    end

    nil
  end

  def self.last_file_updated
    if Rails.env.production?
      @last_file_updated ||= if File.exist?(MANIFEST_FULL_PATH)
        File.readlines(MANIFEST_FULL_PATH, 'r')[0]
      else
        mtime = max_file_mtime
        FileUtils.mkdir_p(MANIFEST_DIR)
        File.open(MANIFEST_FULL_PATH, "w") { |f| f.print(mtime) }
        mtime
      end
    else
      max_file_mtime
    end
  end

  def self.max_file_mtime
    globs = ["#{Rails.root}/app/assets/stylesheets/**/*.*css",
             "#{Rails.root}/app/assets/images/**/*.*"]

    Discourse.plugins.map { |plugin| File.dirname(plugin.path) }.each do |path|
      globs << "#{path}/plugin.rb"
      globs << "#{path}/assets/stylesheets/**/*.*css"
    end

    globs.map do |pattern|
      Dir.glob(pattern).map { |x| File.mtime(x) }.max
    end.compact.max.to_i
  end

  def self.cache_fullpath
    path = "#{Rails.root}/#{CACHE_PATH}"
    return path if !Rails.env.test?
    File.join(path, "test_#{ENV['TEST_ENV_NUMBER'].presence || '0'}")
  end

  attr_reader :theme_ids

  def initialize(theme_id: nil)
    @theme_id = theme_id
    @theme_ids = Theme.transform_ids(@theme_id)
    @themes_cache = {}
  end

  def cache
    self.class.cache
  end

  def get_theme(theme_id)
    if theme = @themes_cache[theme_id]
      theme
    else
      load_themes([theme_id]).first
    end
  end

  def load_themes(theme_ids)
    themes = []
    to_load_theme_ids = []

    theme_ids.each do |theme_id|
      if @themes_cache[theme_id]
        themes << @themes_cache[theme_id]
      else
        to_load_theme_ids << theme_id
      end
    end

    Theme
      .where(id: to_load_theme_ids)
      .includes(:yaml_theme_fields, :theme_settings, :upload_fields, :builder_theme_fields)
      .each do |theme|

      @themes_cache[theme.id] = theme
      themes << theme
    end

    themes
  end

  def stylesheet_data(target = :desktop)
    stylesheet_details(target, "all")
  end

  def stylesheet_link_tag(target = :desktop, media = 'all')
    stylesheets = stylesheet_details(target, media)
    stylesheets.map do |stylesheet|
      href = stylesheet[:new_href]
      theme_id = stylesheet[:theme_id]
      data_theme_id = theme_id ? "data-theme-id=\"#{theme_id}\"" : ""
      theme_name = stylesheet[:theme_name]
      data_theme_name = theme_name ? "data-theme-name=\"#{CGI.escapeHTML(theme_name)}\"" : ""
      %[<link href="#{href}" media="#{media}" rel="stylesheet" data-target="#{target}" #{data_theme_id} #{data_theme_name}/>]
    end.join("\n").html_safe
  end

  def stylesheet_details(target = :desktop, media = 'all')
    target = target.to_sym
    current_hostname = Discourse.current_hostname
    is_theme_target = !!(target.to_s =~ THEME_REGEX)

    array_cache_key = is_theme_target ?
      "array_themes_#{@theme_ids.join(",")}_#{target}_#{current_hostname}" :
      "array_#{target}_#{current_hostname}"

    stylesheets = cache[array_cache_key]
    return stylesheets if stylesheets.present?

    @@lock.synchronize do
      stylesheets = []

      if is_theme_target
        scss_checker = ScssChecker.new(target, @theme_ids)
        themes = load_themes(@theme_ids)
        themes.each do |theme|
          theme_id = theme&.id
          data = { target: target, theme_id: theme_id, theme_name: theme&.name.downcase, remote: theme.remote_theme_id? }
          builder = Builder.new(target: target, theme: theme, manager: self)

          next if builder.theme&.component && !scss_checker.has_scss(theme_id)
          builder.compile unless File.exist?(builder.stylesheet_fullpath)
          href = builder.stylesheet_path(current_hostname)

          data[:new_href] = href
          stylesheets << data
        end

        if stylesheets.size > 1
          stylesheets = stylesheets.sort_by do |s|
            [
              s[:remote] ? 0 : 1,
              s[:theme_id] == @theme_id ? 1 : 0,
              s[:theme_name]
            ]
          end
        end
      else
        builder = Builder.new(target: target, manager: self)
        builder.compile unless File.exist?(builder.stylesheet_fullpath)
        href = builder.stylesheet_path(current_hostname)

        data = { target: target, new_href: href }
        stylesheets << data
      end

      cache.defer_set(array_cache_key, stylesheets.freeze)
      stylesheets
    end
  end

  def color_scheme_stylesheet_details(color_scheme_id = nil, media)
    theme_id = @theme_id || SiteSetting.default_theme_id

    color_scheme = begin
      ColorScheme.find(color_scheme_id)
    rescue
      # don't load fallback when requesting dark color scheme
      return false if media != "all"

      get_theme(theme_id)&.color_scheme || ColorScheme.base
    end

    return false if !color_scheme

    target = COLOR_SCHEME_STYLESHEET.to_sym
    current_hostname = Discourse.current_hostname
    cache_key = self.class.color_scheme_cache_key(color_scheme, theme_id)
    stylesheets = cache[cache_key]
    return stylesheets if stylesheets.present?

    stylesheet = { color_scheme_id: color_scheme.id }

    theme = get_theme(theme_id)

    builder = Builder.new(
      target: target,
      theme: get_theme(theme_id),
      color_scheme: color_scheme,
      manager: self
    )

    builder.compile unless File.exist?(builder.stylesheet_fullpath)

    href = builder.stylesheet_path(current_hostname)
    stylesheet[:new_href] = href
    cache.defer_set(cache_key, stylesheet.freeze)
    stylesheet
  end

  def color_scheme_stylesheet_link_tag(color_scheme_id = nil, media = 'all')
    stylesheet = color_scheme_stylesheet_details(color_scheme_id, media)

    return '' if !stylesheet

    href = stylesheet[:new_href]

    css_class = media == 'all' ? "light-scheme" : "dark-scheme"

    %[<link href="#{href}" media="#{media}" rel="stylesheet" class="#{css_class}"/>].html_safe
  end
end
