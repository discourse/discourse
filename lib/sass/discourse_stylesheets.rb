require_dependency 'sass/discourse_sass_compiler'

class DiscourseStylesheets

  CACHE_PATH = 'uploads/stylesheet-cache'

  @lock = Mutex.new

  def self.stylesheet_link_tag(target = :desktop)
    builder = self.new(target)
    @lock.synchronize do
      builder.compile unless File.exists?(builder.stylesheet_fullpath)
      builder.ensure_digestless_file
      %[<link href="#{Rails.env.production? ? builder.stylesheet_relpath : builder.stylesheet_relpath_no_digest + '?body=1'}" media="screen" rel="stylesheet" />].html_safe
    end
  end

  def self.compile(target = :desktop)
    @lock.synchronize do
      builder = self.new(target)
      builder.compile
      builder.stylesheet_filename
    end
  end


  def initialize(target = :desktop)
    @target = target
  end

  def compile
    scss = File.read("#{Rails.root}/app/assets/stylesheets/#{@target}.scss")
    css = begin
      DiscourseSassCompiler.compile(scss, @target)
    rescue Sass::SyntaxError => e
      Rails.logger.error "Stylesheet failed to compile for '#{@target}'! Recompiling without plugins and theming."
      Rails.logger.error e.sass_backtrace_str("#{@target} stylesheet")
      DiscourseSassCompiler.compile(scss + DiscourseSassCompiler.error_as_css(e, "#{@target} stylesheet"), @target, safe: true)
    end
    FileUtils.mkdir_p(cache_fullpath)
    File.open(stylesheet_fullpath, "w") do |f|
      f.puts css
    end
    css
  end

  def ensure_digestless_file
    unless File.exist?(stylesheet_fullpath_no_digest) && File.mtime(stylesheet_fullpath) == File.mtime(stylesheet_fullpath_no_digest)
      FileUtils.cp(stylesheet_fullpath, stylesheet_fullpath_no_digest)
    end
  end

  def cache_fullpath
    "#{Rails.root}/public/#{CACHE_PATH}"
  end

  def stylesheet_fullpath
    "#{cache_fullpath}/#{stylesheet_filename}"
  end
  def stylesheet_fullpath_no_digest
    "#{cache_fullpath}/#{stylesheet_filename_no_digest}"
  end

  def stylesheet_relpath
    "/#{CACHE_PATH}/#{stylesheet_filename}"
  end
  def stylesheet_relpath_no_digest
    "/#{CACHE_PATH}/#{stylesheet_filename_no_digest}"
  end

  def stylesheet_filename
    "#{@target}_#{digest}.css"
  end
  def stylesheet_filename_no_digest
    "#{@target}.css"
  end

  def digest
    @digest ||= begin
      # Watch for file changes unless in production env.
      # In production, file changes only happen during deploy, followed by assets:precompile.
      last_file_updated = if Rails.env.production?
        0
      else
        [ Dir.glob("#{Rails.root}/app/assets/stylesheets/**/*.*css").map {|x| File.mtime(x) }.max,
          Dir.glob("#{Rails.root}/plugins/**/assets/stylesheets/**/*.*css").map {|x| File.mtime(x) }.max ].max.to_i
      end

      theme = (cs = ColorScheme.enabled) ? "#{cs.id}-#{cs.version}" : 0

      # digest encodes the things that trigger a recompile
      Digest::SHA1.hexdigest("#{RailsMultisite::ConnectionManagement.current_db}-#{theme}-#{last_file_updated}")
    end
  end
end
