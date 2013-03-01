class SiteCustomization < ActiveRecord::Base
  ENABLED_KEY = '7e202ef2-56d7-47d5-98d8-a9c8d15e57dd'
  # placing this in uploads to ease deployment rules
  CACHE_PATH = 'uploads/stylesheet-cache'
  @lock = Mutex.new

  before_create do
    self.position ||= (SiteCustomization.maximum(:position) || 0) + 1
    self.enabled ||= false
    self.key ||= SecureRandom.uuid
    true
  end

  before_save do
    if stylesheet_changed?
      begin
        self.stylesheet_baked = Sass.compile stylesheet
      rescue Sass::SyntaxError => e
        error = e.sass_backtrace_str("custom stylesheet")
        error.gsub!("\n", '\A ')
        error.gsub!("'", '\27 ')

        self.stylesheet_baked =
"#main {display: none;}
footer {white-space: pre; margin-left: 100px;}
footer:after{ content: '#{error}' }"
      end
    end
  end

  after_save do
    if stylesheet_changed?
      if File.exists?(stylesheet_fullpath)
        File.delete stylesheet_fullpath
      end
    end
    remove_from_cache!
    if stylesheet_changed?
      ensure_stylesheet_on_disk!
      MessageBus.publish "/file-change/#{key}", stylesheet_hash
    end
    MessageBus.publish "/header-change/#{key}", header if header_changed?

  end

  after_destroy do
    if File.exists?(stylesheet_fullpath)
      File.delete stylesheet_fullpath
    end
    self.remove_from_cache!
  end

  def self.enabled_key
    ENABLED_KEY.dup << RailsMultisite::ConnectionManagement.current_db
  end

  def self.enabled_style_key
    @cache ||= {}
    preview_style = @cache[enabled_key]
    return if preview_style == :none
    return preview_style if preview_style

    @lock.synchronize do
      style = where(enabled: true).first
      if style
        @cache[enabled_key] = style.key
      else
        @cache[enabled_key] = :none
        nil
      end
    end
  end

  def self.custom_stylesheet(preview_style)
    preview_style ||= enabled_style_key
    style = lookup_style(preview_style)
    style.stylesheet_link_tag.html_safe if style
  end

  def self.custom_header(preview_style)
    preview_style ||= enabled_style_key
    style = lookup_style(preview_style)
    if style && style.header
      style.header.html_safe
    else
      ""
    end
  end

  def self.override_default_style(preview_style)
    preview_style ||= enabled_style_key
    style = lookup_style(preview_style)
    style.override_default_style if style
  end

  def self.lookup_style(key)
    return if key.blank?

    # cache is cross site resiliant cause key is secure random
    @cache ||= {}
    ensure_cache_listener
    style = @cache[key]
    return style if style

    @lock.synchronize do
      style = where(key: key).first
      style.ensure_stylesheet_on_disk! if style
      @cache[key] = style
    end
  end

  def self.ensure_cache_listener
    unless @subscribed
      klass = self
      MessageBus.subscribe("/site_customization") do |msg|
        message = msg.data
        klass.remove_from_cache!(message["key"], false)
      end

      @subscribed = true
    end
  end

  def self.remove_from_cache!(key, broadcast = true)
    MessageBus.publish('/site_customization', key: key) if broadcast
    if @cache
      @lock.synchronize do
        @cache[key] = nil
      end
    end
  end

  def remove_from_cache!
    self.class.remove_from_cache!(self.class.enabled_key)
    self.class.remove_from_cache!(key)
  end

  def stylesheet_hash
    Digest::MD5.hexdigest(stylesheet)
  end

  def cache_fullpath
    "#{Rails.root}/public/#{CACHE_PATH}"
  end

  def ensure_stylesheet_on_disk!
    path = stylesheet_fullpath
    dir = cache_fullpath
    FileUtils.mkdir_p(dir)
    unless File.exists?(path)
      File.open(path, "w") do |f|
        f.puts stylesheet_baked
      end
    end
  end

  def stylesheet_filename
    "/#{self.key}.css"
  end

  def stylesheet_fullpath
    "#{cache_fullpath}#{stylesheet_filename}"
  end

  def stylesheet_link_tag
    return "" unless stylesheet.present?
    return @stylesheet_link_tag if @stylesheet_link_tag
    ensure_stylesheet_on_disk!
    @stylesheet_link_tag = "<link class=\"custom-css\" rel=\"stylesheet\" href=\"/#{CACHE_PATH}#{stylesheet_filename}?#{stylesheet_hash}\" type=\"text/css\" media=\"screen\">"
  end
end
