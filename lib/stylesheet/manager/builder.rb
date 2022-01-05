# frozen_string_literal: true

class Stylesheet::Manager::Builder
  attr_reader :theme

  def initialize(target: :desktop, theme: nil, color_scheme: nil, manager:)
    @target = target
    @theme = theme
    @color_scheme = color_scheme
    @manager = manager
  end

  def compile(opts = {})
    if !opts[:force]
      if File.exist?(stylesheet_fullpath)
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
      elsif @target.to_s == Stylesheet::Manager::COLOR_SCHEME_STYLESHEET
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
      "#{@target}_#{theme&.id}"
    elsif @color_scheme
      "#{@target}_#{scheme_slug}_#{@color_scheme&.id.to_s}_#{@theme&.id}"
    else
      scheme_string = theme&.color_scheme ? "_#{theme.color_scheme.id}" : ""
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
    !!(@target.to_s =~ Stylesheet::Manager::THEME_REGEX)
  end

  def is_color_scheme?
    !!(@target.to_s == Stylesheet::Manager::COLOR_SCHEME_STYLESHEET)
  end

  def scheme_slug
    Slug.for(ActiveSupport::Inflector.transliterate(@color_scheme.name), 'scheme')
  end

  # digest encodes the things that trigger a recompile
  def digest
    @digest ||= begin
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
    if [:mobile_theme, :desktop_theme].include?(@target)
      resolve_baked_field(@target.to_s.sub("_theme", ""), :scss)
    elsif @target == :embedded_theme
      resolve_baked_field(:common, :embedded_scss)
    else
      raise "attempting to look up theme digest for invalid field"
    end
  end

  def theme_digest
    Digest::SHA1.hexdigest(scss_digest.to_s + color_scheme_digest.to_s + settings_digest + uploads_digest)
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

    fields = themes.each_with_object([]) do |theme, array|
      array.concat(theme.yaml_theme_fields.map(&:updated_at))
    end

    settings = themes.each_with_object([]) do |theme, array|
      array.concat(theme.theme_settings.map(&:updated_at))
    end

    timestamps = fields.concat(settings).map!(&:to_f).sort!.join(",")

    Digest::SHA1.hexdigest(timestamps)
  end

  def uploads_digest
    sha1s = []

    (theme&.upload_fields || []).map do |upload_field|
      sha1s << upload_field.upload.sha1
    end

    Digest::SHA1.hexdigest(sha1s.sort!.join("\n"))
  end

  def default_digest
    Digest::SHA1.hexdigest "default-#{Stylesheet::Manager.last_file_updated}-#{plugins_digest}"
  end

  def color_scheme_digest
    cs = @color_scheme || theme&.color_scheme

    categories_updated = Stylesheet::Manager.cache.defer_get_set("categories_updated") do
      Category
        .where("uploaded_background_id IS NOT NULL")
        .pluck(:updated_at)
        .map(&:to_i)
        .sum
    end

    fonts = "#{SiteSetting.base_font}-#{SiteSetting.heading_font}"

    if cs || categories_updated > 0
      theme_color_defs = resolve_baked_field(:common, :color_definitions)
      Digest::SHA1.hexdigest "#{RailsMultisite::ConnectionManagement.current_db}-#{cs&.id}-#{cs&.version}-#{theme_color_defs}-#{Stylesheet::Manager.last_file_updated}-#{categories_updated}-#{fonts}"
    else
      digest_string = "defaults-#{Stylesheet::Manager.last_file_updated}-#{fonts}"

      if cdn_url = GlobalSetting.cdn_url
        digest_string = "#{digest_string}-#{cdn_url}"
      end

      Digest::SHA1.hexdigest digest_string
    end
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
    targets = [Theme.targets[target.to_sym], Theme.targets[:common]]

    @manager.load_themes(theme_ids).each do |theme|
      theme.builder_theme_fields.each do |theme_field|
        if theme_field.name == name.to_s && targets.include?(theme_field.target_id)
          baked_fields << theme_field
        end
      end
    end

    baked_fields.map do |f|
      f.ensure_baked!
      f.value_baked || f.value
    end.join("\n")
  end
end
