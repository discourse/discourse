class Page < ActiveRecord::Base
  # TODO: New key different from site customization? How to generate?
  ENABLED_KEY = '7e202ef2-56d7-47d5-98d8-a9c8d15e57dd'
  # placing this in uploads to ease deployment rules
  CACHE_PATH = 'uploads/page-cache'
  @lock = Mutex.new

  before_create do
    self.position ||= (Page.maximum(:position) || 0) + 1
    self.enabled ||= false
    self.key ||= SecureRandom.uuid
    true
  end

  before_save do
    if route_changed?
      # Don't allow paths like ".." or "/" or anything like that.
      self.route.gsub!(/[^a-z0-9\_\-]/, '')
    end
  end

  after_save do
    if page_changed?
      if File.exists?(page_fullpath)
        File.delete page_fullpath
      end
    end
    self.remove_from_cache!
    
    if page_changed?
      ensure_page_on_disk!
      MessageBus.publish "/file-change/#{key}", page_hash
    end
  end

  after_destroy do
    if File.exists?(page_fullpath)
      File.delete page_fullpath
    end
    self.remove_from_cache!
  end

  def self.enabled_key
    ENABLED_KEY.dup << RailsMultisite::ConnectionManagement.current_db
  end

  def self.enabled_page_key
    @cache ||= {}
    preview_page = @cache[enabled_key]
    return if preview_page == :none
    return preview_page if preview_page

    @lock.synchronize do
      page = where(enabled: true).first
      if page
        @cache[enabled_key] = page.key
      else
        @cache[enabled_key] = :none
        nil
      end
    end
  end

  def self.page()
    preview_page ||= enabled_page_key
    page = lookup_page(preview_page)
    page.html_safe if page
  end

  def self.lookup_page(key)
    return if key.blank?

    # cache is cross site resiliant cause key is secure random
    @cache ||= {}
    ensure_cache_listener
    page = @cache[key]
    return page if page

    @lock.synchronize do
      page = where(key: key).first
      page.ensure_page_on_disk! if page
      @cache[key] = page
    end
  end

  def self.ensure_cache_listener
    unless @subscribed
      klass = self
      MessageBus.subscribe("/page") do |msg|
        message = msg.data
        klass.remove_from_cache!(message["key"], false)
      end
      @subscribed = true
    end
  end

  def self.remove_from_cache!(key, broadcast = true)
    MessageBus.publish('/page', key: key) if broadcast
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

  def page_hash
    Digest::MD5.hexdigest(page)
  end

  def cache_fullpath
    "#{Rails.root}/public/#{CACHE_PATH}"
  end

  def ensure_page_on_disk!
    path = page_fullpath
    dir = cache_fullpath
    FileUtils.mkdir_p(dir)
    unless File.exists?(path)
      File.open(path, "w") do |f|
        f.puts page
      end
    end
  end

  def page_filename
    "/#{self.key}.html"
  end

  def page_fullpath
    "#{cache_fullpath}#{page_filename}"
  end

end
