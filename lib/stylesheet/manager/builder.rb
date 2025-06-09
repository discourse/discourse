# frozen_string_literal: true

class Stylesheet::Manager::Builder
  attr_reader :theme

  def initialize(target: :desktop, theme: nil, color_scheme: nil, manager:, dark: false)
    @target = target
    @theme = theme
    @color_scheme = color_scheme
    @manager = manager
    @dark = dark
  end

  def compile(opts = {})
    if !opts[:force]
      if File.exist?(stylesheet_fullpath)
        if !StylesheetCache.where(target: qualified_target, digest: digest).exists?
          begin
            source_map =
              begin
                File.read(source_map_fullpath)
              rescue Errno::ENOENT
              end

            StylesheetCache.add(
              qualified_target,
              digest,
              File.read(stylesheet_fullpath),
              source_map,
            )
          rescue => e
            Rails.logger.warn "Completely unexpected error adding contents of '#{stylesheet_fullpath}' to cache #{e}"
          end
        end
        return true
      end
    end

    rtl = @target.to_s.end_with?("_rtl")
    css, source_map =
      with_load_paths do |load_paths|
        Stylesheet::Compiler.compile_asset(
          @target.to_s.gsub(/_rtl\z/, "").to_sym,
          rtl: rtl,
          theme_id: theme&.id,
          theme_variables: theme&.scss_variables.to_s,
          source_map_file: source_map_url_relative_from_stylesheet,
          color_scheme_id: @color_scheme&.id,
          load_paths: load_paths,
          dark: @dark,
          strict_deprecations: %i[desktop mobile admin wizard].include?(@target),
        )
      rescue SassC::SyntaxError, SassC::NotRenderedError, DiscourseJsProcessor::TranspileError => e
        if Stylesheet::Manager::THEME_REGEX.match?(@target.to_s)
          # no special errors for theme, handled in theme editor
          ["/* SCSS compilation error: #{e.message} */", nil]
        elsif @target.to_s == Stylesheet::Manager::COLOR_SCHEME_STYLESHEET && Rails.env.production?
          # log error but do not crash for errors in color definitions SCSS
          Rails.logger.error "SCSS compilation error: #{e.message}"
          ["/* SCSS compilation error: #{e.message} */", nil]
        else
          raise Discourse::ScssError, e.message
        end
      end

    FileUtils.mkdir_p(cache_fullpath)

    File.open(stylesheet_fullpath, "w") { |f| f.puts css }

    File.open(source_map_fullpath, "w") { |f| f.puts source_map } if source_map.present?

    begin
      StylesheetCache.add(qualified_target, digest, css, source_map)
    rescue => e
      Rails.logger.warn "Completely unexpected error adding item to cache #{e}"
    end
    css
  end

  def current_hostname
    Discourse.current_hostname
  end

  def cache_fullpath
    Stylesheet::Manager.cache_fullpath
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

  def source_map_url_relative_from_stylesheet
    "#{source_map_filename}?__ws=#{current_hostname}"
  end

  def stylesheet_fullpath_no_digest
    "#{cache_fullpath}/#{stylesheet_filename_no_digest}"
  end

  def stylesheet_absolute_url
    "#{GlobalSetting.cdn_url}#{stylesheet_relpath}?__ws=#{current_hostname}"
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
    dark_string = @dark ? "_dark" : ""
    if is_theme?
      "#{@target}_#{theme&.id}"
    elsif @color_scheme
      "#{@target}_#{scheme_slug}_#{@color_scheme&.id}_#{@theme&.id}#{dark_string}"
    else
      scheme_string = theme&.color_scheme ? "_#{theme.color_scheme.id}" : ""
      "#{@target}#{scheme_string}#{dark_string}"
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
    !!(@target.to_s =~ Stylesheet::Manager::THEME_REGEX)
  end

  def is_color_scheme?
    !!(@target.to_s == Stylesheet::Manager::COLOR_SCHEME_STYLESHEET)
  end

  def scheme_slug
    Slug.for(ActiveSupport::Inflector.transliterate(@color_scheme.name), "scheme")
  end

  # digest encodes the things that trigger a recompile
  def digest
    @digest ||=
      begin
        if is_theme?
          theme_digest
        elsif is_color_scheme?
          color_scheme_digest
        else
          default_digest
        end
      end
  end

  def with_load_paths
    if theme
      theme.with_scss_load_paths { |p| yield p }
    else
      yield nil
    end
  end

  def scss_digest
    base_target = @target.to_s.delete_suffix("_rtl").to_sym
    if %i[common_theme mobile_theme desktop_theme].include?(base_target)
      resolve_baked_field(base_target.to_s.delete_suffix("_theme"), :scss)
    elsif @target == :embedded_theme
      resolve_baked_field(:common, :embedded_scss)
    else
      raise "attempting to look up theme digest for invalid field"
    end
  end

  def theme_digest
    Digest::SHA1.hexdigest(
      scss_digest.to_s + color_scheme_digest.to_s + settings_digest + uploads_digest +
        current_hostname,
    )
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
    themes =
      if !theme
        []
      elsif Theme.is_parent_theme?(theme.id)
        @manager.load_themes(@manager.theme_ids)
      else
        [@manager.get_theme(theme.id)]
      end

    fields =
      themes.each_with_object([]) do |theme, array|
        array.concat(theme.yaml_theme_fields.map(&:updated_at))
      end

    settings =
      themes.each_with_object([]) do |theme, array|
        array.concat(theme.theme_settings.map(&:updated_at))
      end

    timestamps = fields.concat(settings).map!(&:to_f).sort!.join(",")

    Digest::SHA1.hexdigest(timestamps)
  end

  def uploads_digest
    sha1s = []

    (theme&.upload_fields || []).map { |upload_field| sha1s << upload_field.upload&.sha1 }

    Digest::SHA1.hexdigest(sha1s.compact.sort!.join("\n"))
  end

  def default_digest
    Digest::SHA1.hexdigest "default-#{Stylesheet::Manager.fs_asset_cachebuster}-#{plugins_digest}-#{current_hostname}"
  end

  def color_scheme_digest
    cs = @color_scheme || theme&.color_scheme

    fonts = "#{SiteSetting.base_font}-#{SiteSetting.heading_font}"

    digest_string = "#{current_hostname}-"
    if cs
      theme_color_defs = resolve_baked_field(:common, :color_definitions)
      dark_string = @dark ? "-dark" : ""
      digest_string +=
        "#{RailsMultisite::ConnectionManagement.current_db}-#{cs&.id}-#{cs&.version}-#{theme_color_defs}-#{Stylesheet::Manager.fs_asset_cachebuster}-#{fonts}#{dark_string}"
    else
      digest_string += "defaults-#{Stylesheet::Manager.fs_asset_cachebuster}-#{fonts}"

      if cdn_url = GlobalSetting.cdn_url
        digest_string += "-#{cdn_url}"
      end
    end
    Digest::SHA1.hexdigest digest_string
  end

  def resolve_baked_field(target, name)
    theme_ids =
      if !theme
        []
      elsif Theme.is_parent_theme?(theme.id)
        @manager.theme_ids
      else
        [theme.id]
      end

    theme_ids = [theme_ids.first] if name != :color_definitions

    baked_fields = []
    target_id = Theme.targets[target.to_sym]

    @manager
      .load_themes(theme_ids)
      .each do |theme|
        theme.builder_theme_fields.each do |theme_field|
          if theme_field.name == name.to_s && theme_field.target_id == target_id
            baked_fields << theme_field
          end
        end
      end

    baked_fields
      .map do |f|
        f.ensure_baked!
        f.value_baked || f.value
      end
      .join("\n")
  end
end
