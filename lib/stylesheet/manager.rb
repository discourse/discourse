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

  @lock = Mutex.new

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

  def self.stylesheet_data(target = :desktop, theme_ids = :missing)
    stylesheet_details(target, "all", theme_ids)
  end

  def self.stylesheet_link_tag(target = :desktop, media = 'all', theme_ids = :missing)
    stylesheets = stylesheet_details(target, media, theme_ids)
    stylesheets.map do |stylesheet|
      href = stylesheet[:new_href]
      theme_id = stylesheet[:theme_id]
      data_theme_id = theme_id ? "data-theme-id=\"#{theme_id}\"" : ""
      %[<link href="#{href}" media="#{media}" rel="stylesheet" data-target="#{target}" #{data_theme_id}/>]
    end.join("\n").html_safe
  end

  def self.stylesheet_details(target = :desktop, media = 'all', theme_ids = :missing)
    if theme_ids == :missing
      theme_ids = [SiteSetting.default_theme_id]
    end

    target = target.to_sym

    theme_ids = [theme_ids] unless Array === theme_ids
    theme_ids = [theme_ids.first] unless target =~ THEME_REGEX
    include_components = !!(target =~ THEME_REGEX)

    theme_ids = Theme.transform_ids(theme_ids, extend: include_components)

    current_hostname = Discourse.current_hostname

    array_cache_key = "array_themes_#{theme_ids.join(",")}_#{target}_#{current_hostname}"
    stylesheets = cache[array_cache_key]
    return stylesheets if stylesheets.present?

    @lock.synchronize do
      stylesheets = []
      theme_ids.each do |theme_id|
        data = { target: target }
        cache_key = "path_#{target}_#{theme_id}_#{current_hostname}"
        href = cache[cache_key]

        unless href
          builder = self.new(target, theme_id)
          is_theme = builder.is_theme?
          has_theme = builder.theme.present?

          if is_theme && !has_theme
            next
          else
            next if builder.theme&.component && !builder.theme&.has_scss(target)
            data[:theme_id] = builder.theme.id if has_theme && is_theme
            builder.compile unless File.exists?(builder.stylesheet_fullpath)
            href = builder.stylesheet_path(current_hostname)
          end
          cache[cache_key] = href
        end

        data[:theme_id] = theme_id if theme_id.present? && data[:theme_id].blank?
        data[:new_href] = href
        stylesheets << data
      end
      cache[array_cache_key] = stylesheets.freeze
      stylesheets
    end
  end

  def self.color_scheme_stylesheet_details(color_scheme_id = nil, media, theme_id)
    theme_id = theme_id || SiteSetting.default_theme_id

    color_scheme = begin
      ColorScheme.find(color_scheme_id)
    rescue
      # don't load fallback when requesting dark color scheme
      return false if media != "all"

      Theme.find_by_id(theme_id)&.color_scheme || ColorScheme.base
    end

    return false if !color_scheme

    target = COLOR_SCHEME_STYLESHEET.to_sym
    current_hostname = Discourse.current_hostname
    cache_key = color_scheme_cache_key(color_scheme, theme_id)
    stylesheets = cache[cache_key]
    return stylesheets if stylesheets.present?

    stylesheet = { color_scheme_id: color_scheme&.id }

    builder = self.new(target, theme_id, color_scheme)

    builder.compile unless File.exists?(builder.stylesheet_fullpath)

    href = builder.stylesheet_path(current_hostname)
    stylesheet[:new_href] = href
    cache[cache_key] = stylesheet.freeze
    stylesheet
  end

  def self.color_scheme_stylesheet_link_tag(color_scheme_id = nil, media = 'all', theme_ids = nil)
    theme_id = theme_ids&.first
    stylesheet = color_scheme_stylesheet_details(color_scheme_id, media, theme_id)
    return '' if !stylesheet

    href = stylesheet[:new_href]

    css_class = media == 'all' ? "light-scheme" : "dark-scheme"

    %[<link href="#{href}" media="#{media}" rel="stylesheet" class="#{css_class}"/>].html_safe
  end

  def self.color_scheme_cache_key(color_scheme, theme_id = nil)
    color_scheme_name = Slug.for(color_scheme.name) + color_scheme&.id.to_s
    theme_string = theme_id ? "_theme#{theme_id}" : ""
    "#{COLOR_SCHEME_STYLESHEET}_#{color_scheme_name}#{theme_string}_#{Discourse.current_hostname}"
  end

  def self.precompile_css
    themes = Theme.where('user_selectable OR id = ?', SiteSetting.default_theme_id).pluck(:id, :name, :color_scheme_id)
    themes << nil

    color_schemes = ColorScheme.where(user_selectable: true).to_a
    color_schemes << ColorScheme.find_by(id: SiteSetting.default_dark_mode_color_scheme_id)
    color_schemes = color_schemes.compact.uniq

    targets = [:desktop, :mobile, :desktop_rtl, :mobile_rtl, :desktop_theme, :mobile_theme, :admin, :wizard]
    targets += Discourse.find_plugin_css_assets(include_disabled: true, mobile_view: true, desktop_view: true)

    themes.each do |id, name, color_scheme_id|
      targets.each do |target|
        theme_id = id || SiteSetting.default_theme_id
        next if target =~ THEME_REGEX && theme_id == -1
        cache_key = "#{target}_#{theme_id}"

        STDERR.puts "precompile target: #{target} #{name}"
        builder = self.new(target, theme_id)
        builder.compile(force: true)
        cache[cache_key] = nil
      end

      theme_color_scheme = ColorScheme.find_by_id(color_scheme_id) || ColorScheme.base

      [theme_color_scheme, *color_schemes].uniq.each do |scheme|
        STDERR.puts "precompile target: #{COLOR_SCHEME_STYLESHEET} #{name} (#{scheme.name})"

        builder = self.new(COLOR_SCHEME_STYLESHEET, id, scheme)
        builder.compile(force: true)
      end
      clear_color_scheme_cache!
    end

    nil
  end

  def self.last_file_updated
    if Rails.env.production?
      @last_file_updated ||= if File.exists?(MANIFEST_FULL_PATH)
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
    "#{Rails.root}/#{CACHE_PATH}"
  end

  def initialize(target = :desktop, theme_id = nil, color_scheme = nil)
    @target = target
    @theme_id = theme_id
    @color_scheme = color_scheme
  end

  def compile(opts = {})
    unless opts[:force]
      if File.exists?(stylesheet_fullpath)
        unless StylesheetCache.where(target: qualified_target, digest: digest).exists?
          begin
            source_map = begin
              File.read(source_map_fullpath)
            rescue Errno::ENOENT
            end

            StylesheetCache.add(qualified_target, digest, File.read(stylesheet_fullpath), source_map)
          rescue => e
            Rails.logger.warn "Completely unexpected error adding contents of '#{stylesheet_fullpath}' to cache #{e}"
          end
        end
        return true
      end
    end

    rtl = @target.to_s =~ /_rtl$/
    css, source_map = with_load_paths do |load_paths|
      Stylesheet::Compiler.compile_asset(
        @target,
         rtl: rtl,
         theme_id: theme&.id,
         theme_variables: theme&.scss_variables.to_s,
         source_map_file: source_map_filename,
         color_scheme_id: @color_scheme&.id,
         load_paths: load_paths
      )
    rescue SassC::SyntaxError => e
      if Stylesheet::Importer::THEME_TARGETS.include?(@target.to_s)
        # no special errors for theme, handled in theme editor
        ["", nil]
      elsif @target.to_s == COLOR_SCHEME_STYLESHEET
        # log error but do not crash for errors in color definitions SCSS
        Rails.logger.error "SCSS compilation error: #{e.message}"
        ["", nil]
      else
        raise Discourse::ScssError, e.message
      end
    end

    FileUtils.mkdir_p(cache_fullpath)

    File.open(stylesheet_fullpath, "w") do |f|
      f.puts css
    end

    if source_map.present?
      File.open(source_map_fullpath, "w") do |f|
        f.puts source_map
      end
    end

    begin
      StylesheetCache.add(qualified_target, digest, css, source_map)
    rescue => e
      Rails.logger.warn "Completely unexpected error adding item to cache #{e}"
    end
    css
  end

  def cache_fullpath
    self.class.cache_fullpath
  end

  def stylesheet_fullpath
    "#{cache_fullpath}/#{stylesheet_filename}"
  end

  def source_map_fullpath
    "#{cache_fullpath}/#{source_map_filename}"
  end

  def source_map_filename
    "#{stylesheet_filename}.map"
  end

  def stylesheet_fullpath_no_digest
    "#{cache_fullpath}/#{stylesheet_filename_no_digest}"
  end

  def stylesheet_cdnpath(hostname)
    "#{GlobalSetting.cdn_url}#{stylesheet_relpath}?__ws=#{hostname}"
  end

  def stylesheet_path(hostname)
    stylesheet_cdnpath(hostname)
  end

  def root_path
    "#{GlobalSetting.relative_url_root}/"
  end

  def stylesheet_relpath
    "#{root_path}stylesheets/#{stylesheet_filename}"
  end

  def stylesheet_relpath_no_digest
    "#{root_path}stylesheets/#{stylesheet_filename_no_digest}"
  end

  def qualified_target
    if is_theme?
      "#{@target}_#{theme.id}"
    elsif @color_scheme
      "#{@target}_#{scheme_slug}_#{@color_scheme&.id.to_s}"
    else
      scheme_string = theme && theme.color_scheme ? "_#{theme.color_scheme.id}" : ""
      "#{@target}#{scheme_string}"
    end
  end

  def stylesheet_filename(with_digest = true)
    digest_string = "_#{self.digest}" if with_digest
    "#{qualified_target}#{digest_string}.css"
  end

  def stylesheet_filename_no_digest
    stylesheet_filename(_with_digest = false)
  end

  def is_theme?
    !!(@target.to_s =~ THEME_REGEX)
  end

  def scheme_slug
    Slug.for(ActiveSupport::Inflector.transliterate(@color_scheme.name), 'scheme')
  end

  # digest encodes the things that trigger a recompile
  def digest
    @digest ||= begin
      if is_theme?
        theme_digest
      else
        color_scheme_digest
      end
    end
  end

  def theme
    @theme ||= Theme.find_by(id: @theme_id) || :nil
    @theme == :nil ? nil : @theme
  end

  def with_load_paths
    if theme
      theme.with_scss_load_paths { |p| yield p }
    else
      yield nil
    end
  end

  def theme_digest
    if [:mobile_theme, :desktop_theme].include?(@target)
      scss_digest = theme.resolve_baked_field(:common, :scss)
      scss_digest += theme.resolve_baked_field(@target.to_s.sub("_theme", ""), :scss)
    elsif @target == :embedded_theme
      scss_digest = theme.resolve_baked_field(:common, :embedded_scss)
    else
      raise "attempting to look up theme digest for invalid field"
    end

    Digest::SHA1.hexdigest(scss_digest.to_s + color_scheme_digest.to_s + settings_digest + plugins_digest + uploads_digest)
  end

  # this protects us from situations where new versions of a plugin removed a file
  # old instances may still be serving CSS and not aware of the change
  # so we could end up poisoning the cache with a bad file that can not be removed
  def plugins_digest
    assets = []
    DiscoursePluginRegistry.stylesheets.each { |_, paths| assets += paths.to_a }
    DiscoursePluginRegistry.mobile_stylesheets.each { |_, paths| assets += paths.to_a }
    DiscoursePluginRegistry.desktop_stylesheets.each { |_, paths| assets += paths.to_a }
    Digest::SHA1.hexdigest(assets.sort.join)
  end

  def settings_digest
    theme_ids = Theme.components_for(@theme_id).dup
    theme_ids << @theme_id

    fields = ThemeField.where(
      name: "yaml",
      type_id: ThemeField.types[:yaml],
      theme_id: theme_ids
    ).pluck(:updated_at)

    settings = ThemeSetting.where(theme_id: theme_ids).pluck(:updated_at)
    timestamps = fields.concat(settings).map!(&:to_f).sort!.join(",")

    Digest::SHA1.hexdigest(timestamps)
  end

  def uploads_digest
    Digest::SHA1.hexdigest(ThemeField.joins(:upload).where(id: theme&.all_theme_variables).pluck(:sha1).join(","))
  end

  def color_scheme_digest

    cs = @color_scheme || theme&.color_scheme

    category_updated = Category.where("uploaded_background_id IS NOT NULL").pluck(:updated_at).map(&:to_i).sum
    fonts = "#{SiteSetting.base_font}-#{SiteSetting.heading_font}"

    if cs || category_updated > 0
      theme_color_defs = theme&.resolve_baked_field(:common, :color_definitions)
      Digest::SHA1.hexdigest "#{RailsMultisite::ConnectionManagement.current_db}-#{cs&.id}-#{cs&.version}-#{theme_color_defs}-#{Stylesheet::Manager.last_file_updated}-#{category_updated}-#{fonts}"
    else
      digest_string = "defaults-#{Stylesheet::Manager.last_file_updated}-#{fonts}"

      if cdn_url = GlobalSetting.cdn_url
        digest_string = "#{digest_string}-#{cdn_url}"
      end

      Digest::SHA1.hexdigest digest_string
    end
  end
end
