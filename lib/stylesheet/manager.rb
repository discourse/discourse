require_dependency 'distributed_cache'
require_dependency 'stylesheet/compiler'

module Stylesheet; end

class Stylesheet::Manager

  CACHE_PATH ||= 'tmp/stylesheet-cache'
  MANIFEST_DIR ||= "#{Rails.root}/tmp/cache/assets/#{Rails.env}"
  MANIFEST_FULL_PATH ||= "#{MANIFEST_DIR}/stylesheet-manifest"

  @lock = Mutex.new

  def self.cache
    @cache ||= DistributedCache.new("discourse_stylesheet")
  end

  def self.clear_theme_cache!
    cache.hash.keys.select{|k| k =~ /theme/}.each{|k|cache.delete(k)}
  end

  def self.stylesheet_link_tag(target = :desktop, media = 'all', theme_key = :missing)

    target = target.to_sym

    if theme_key == :missing
      theme_key = SiteSetting.default_theme_key
    end

    cache_key = "#{target}_#{theme_key}"
    tag = cache[cache_key]

    return tag.dup.html_safe if tag

    @lock.synchronize do
      builder = self.new(target, theme_key)
      builder.compile unless File.exists?(builder.stylesheet_fullpath)
      builder.ensure_digestless_file
      tag = %[<link href="#{builder.stylesheet_path}" media="#{media}" rel="stylesheet" data-target="#{target}"/>]
      cache[cache_key] = tag

      tag.dup.html_safe
    end
  end

  def self.precompile_css
    themes = Theme.where('user_selectable OR key = ?', SiteSetting.default_theme_key).pluck(:key,:name)
    themes << nil
    themes.each do |key,name|
      [:desktop, :mobile, :desktop_rtl, :mobile_rtl].each do |target|
        theme_key = key || SiteSetting.default_theme_key
        cache_key = "#{target}_#{theme_key}"

        STDERR.puts "precompile target: #{target} #{name}"
        builder = self.new(target, theme_key)
        builder.compile(force: true)
        cache[cache_key] = nil
      end
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
      globs << "#{path}/**/*.*css"
    end

    globs.map do |pattern|
      Dir.glob(pattern).map { |x| File.mtime(x) }.max
    end.compact.max.to_i
  end

  def initialize(target = :desktop, theme_key)
    @target = target
    @theme_key = theme_key
  end

  def compile(opts={})
    unless opts[:force]
      if File.exists?(stylesheet_fullpath)
        unless StylesheetCache.where(target: qualified_target, digest: digest).exists?
          begin
            source_map = File.read(source_map_fullpath) rescue nil
            StylesheetCache.add(qualified_target, digest, File.read(stylesheet_fullpath), source_map)
          rescue => e
            Rails.logger.warn "Completely unexpected error adding contents of '#{stylesheet_fullpath}' to cache #{e}"
          end
        end
        return true
      end
    end

    rtl = @target.to_s =~ /_rtl$/
    css,source_map = begin
      Stylesheet::Compiler.compile_asset(
        @target,
         rtl: rtl,
         theme_id: theme&.id,
         source_map_file: source_map_filename
      )
    rescue SassC::SyntaxError => e
      Rails.logger.error "Failed to compile #{@target} stylesheet: #{e.message}"
      [Stylesheet::Compiler.error_as_css(e, "#{@target} stylesheet"), nil]
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

  def ensure_digestless_file
    # file without digest is only for auto-reloading css in dev env
    unless Rails.env.production? || (File.exist?(stylesheet_fullpath_no_digest) && File.mtime(stylesheet_fullpath) == File.mtime(stylesheet_fullpath_no_digest))
      FileUtils.cp(stylesheet_fullpath, stylesheet_fullpath_no_digest)
    end
  end

  def self.cache_fullpath
    "#{Rails.root}/#{CACHE_PATH}"
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

  def stylesheet_cdnpath
    "#{GlobalSetting.cdn_url}#{stylesheet_relpath}?__ws=#{Discourse.current_hostname}"
  end

  def stylesheet_path
    if Rails.env.development?
      if @target.to_s =~ /theme/
        stylesheet_relpath
      else
        stylesheet_relpath_no_digest
      end
    else
      stylesheet_cdnpath
    end
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
    stylesheet_filename(_with_digest=false)
  end

  def is_theme?
    !!(@target.to_s =~ /_theme$/)
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
    @theme ||= (Theme.find_by(key: @theme_key) || :nil)
    @theme == :nil ? nil : @theme
  end

  def theme_digest
    scss = ""

    if [:mobile_theme, :desktop_theme].include?(@target)
      scss = theme.resolve_baked_field(:common, :scss)
      scss += theme.resolve_baked_field(@target.to_s.sub("_theme", ""), :scss)
    elsif @target == :embedded_theme
      scss = theme.resolve_baked_field(:common, :embedded_scss)
    else
      raise "attempting to look up theme digest for invalid field"
    end

    Digest::SHA1.hexdigest scss.to_s
  end

  def color_scheme_digest

    cs = theme&.color_scheme
    category_updated = Category.where("uploaded_background_id IS NOT NULL").last_updated_at

    if cs || category_updated > 0
      Digest::SHA1.hexdigest "#{RailsMultisite::ConnectionManagement.current_db}-#{cs&.id}-#{cs&.version}-#{Stylesheet::Manager.last_file_updated}-#{category_updated}"
    else
      digest_string = "defaults-#{Stylesheet::Manager.last_file_updated}"

      if cdn_url = GlobalSetting.cdn_url
        digest_string = "#{digest_string}-#{cdn_url}"
      end

      Digest::SHA1.hexdigest digest_string
    end
  end
end
