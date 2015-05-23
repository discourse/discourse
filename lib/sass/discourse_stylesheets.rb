require_dependency 'sass/discourse_sass_compiler'
require_dependency 'distributed_cache'

class DiscourseStylesheets

  CACHE_PATH ||= 'tmp/stylesheet-cache'
  MANIFEST_DIR ||= "#{Rails.root}/tmp/cache/assets/#{Rails.env}"
  MANIFEST_FULL_PATH ||= "#{MANIFEST_DIR}/stylesheet-manifest"

  @lock = Mutex.new

  def self.cache
    return {} if Rails.env.development?
    @cache ||= DistributedCache.new("discourse_stylesheet")
  end

  def self.stylesheet_link_tag(target = :desktop)

    tag = cache[target]

    return tag.dup.html_safe if tag

    @lock.synchronize do
      builder = self.new(target)
      builder.compile unless File.exists?(builder.stylesheet_fullpath)
      builder.ensure_digestless_file
      tag = %[<link href="#{Rails.env.production? ? builder.stylesheet_cdnpath : builder.stylesheet_relpath_no_digest + '?body=1'}" media="all" rel="stylesheet" />]

      cache[target] = tag

      tag.dup.html_safe
    end
  end

  def self.compile(target = :desktop, opts={})
    @lock.synchronize do
      FileUtils.rm(MANIFEST_FULL_PATH, force: true) if opts[:force]
      builder = self.new(target)
      builder.compile(opts)
      builder.stylesheet_filename
    end
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
    globs = ["#{Rails.root}/app/assets/stylesheets/**/*.*css"]

    for path in (Discourse.plugins || []).map { |plugin| File.dirname(plugin.path) }
      globs += [
        "#{path}/plugin.rb",
        "#{path}/**/*.*css",
      ]
    end

    globs.map do |pattern|
      Dir.glob(pattern).map { |x| File.mtime(x) }.max
    end.compact.max.to_i
  end



  def initialize(target = :desktop)
    @target = target
  end

  def compile(opts={})
    unless opts[:force]
      if File.exists?(stylesheet_fullpath)
        unless StylesheetCache.where(target: @target, digest: digest).exists?
          begin
            StylesheetCache.add(@target, digest, File.read(stylesheet_fullpath))
          rescue => e
            Rails.logger.warn "Completely unexpected error adding contents of '#{stylesheet_fullpath}' to cache #{e}"
          end
        end
        return true
      end
    end

    scss = File.read("#{Rails.root}/app/assets/stylesheets/#{@target}.scss")
    rtl = @target.to_s =~ /_rtl$/
    css = begin
      DiscourseSassCompiler.compile(scss, @target, rtl: rtl)
    rescue Sass::SyntaxError => e
      Rails.logger.error "Stylesheet failed to compile for '#{@target}'! Recompiling without plugins and theming."
      Rails.logger.error e.sass_backtrace_str("#{@target} stylesheet")
      DiscourseSassCompiler.compile(scss + DiscourseSassCompiler.error_as_css(e, "#{@target} stylesheet"), @target, safe: true)
    end
    FileUtils.mkdir_p(cache_fullpath)
    File.open(stylesheet_fullpath, "w") do |f|
      f.puts css
    end
    begin
      StylesheetCache.add(@target, digest, css)
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
  def stylesheet_fullpath_no_digest
    "#{cache_fullpath}/#{stylesheet_filename_no_digest}"
  end

  def stylesheet_cdnpath
    "#{GlobalSetting.cdn_url}#{stylesheet_relpath}?__ws=#{Discourse.current_hostname}"
  end

  def root_path
    "#{GlobalSetting.relative_url_root}/"
  end

  # using uploads cause we already have all the routing in place
  def stylesheet_relpath
    "#{root_path}stylesheets/#{stylesheet_filename}"
  end

  def stylesheet_relpath_no_digest
    "#{root_path}stylesheets/#{stylesheet_filename_no_digest}"
  end

  def stylesheet_filename
    "#{@target}_#{digest}.css"
  end
  def stylesheet_filename_no_digest
    "#{@target}.css"
  end

  # digest encodes the things that trigger a recompile
  def digest
    @digest ||= begin
      theme = (cs = ColorScheme.enabled) ? "#{cs.id}-#{cs.version}" : false
      category_updated = Category.where("background_url IS NOT NULL and background_url != ''").last_updated_at

      if theme || category_updated > 0
        Digest::SHA1.hexdigest "#{RailsMultisite::ConnectionManagement.current_db}-#{theme}-#{DiscourseStylesheets.last_file_updated}-#{category_updated}"
      else
        Digest::SHA1.hexdigest "defaults-#{DiscourseStylesheets.last_file_updated}"
      end
    end
  end
end
