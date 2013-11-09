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
    ['stylesheet', 'mobile_stylesheet'].each do |stylesheet_attr|
      if self.send("#{stylesheet_attr}_changed?")
        begin
          self.send("#{stylesheet_attr}_baked=", Sass.compile(self.send(stylesheet_attr)))
        rescue Sass::SyntaxError => e
          error = e.sass_backtrace_str("custom stylesheet")
          error.gsub!("\n", '\A ')
          error.gsub!("'", '\27 ')

          self.send("#{stylesheet_attr}_baked=",
  "#main {display: none;}
  footer {white-space: pre; margin-left: 100px;}
  footer:after{ content: '#{error}' }")
        end
      end
    end
  end

  after_save do
    if stylesheet_changed?
      File.delete(stylesheet_fullpath) if File.exists?(stylesheet_fullpath)
    end
    if mobile_stylesheet_changed?
      File.delete(stylesheet_fullpath(:mobile)) if File.exists?(stylesheet_fullpath(:mobile))
    end
    remove_from_cache!
    if stylesheet_changed? or mobile_stylesheet_changed?
      ensure_stylesheets_on_disk!
      # TODO: this is broken now because there's mobile stuff too
      MessageBus.publish "/file-change/#{key}", stylesheet_hash
    end
    MessageBus.publish "/header-change/#{key}", header if header_changed?

  end

  after_destroy do
    if File.exists?(stylesheet_fullpath)
      File.delete stylesheet_fullpath
    end
    if File.exists?(stylesheet_fullpath(:mobile))
      File.delete stylesheet_fullpath(:mobile)
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

  def self.custom_stylesheet(preview_style, target=:desktop)
    preview_style ||= enabled_style_key
    style = lookup_style(preview_style)
    style.stylesheet_link_tag(target).html_safe if style
  end

  def self.custom_header(preview_style, target=:desktop)
    preview_style ||= enabled_style_key
    style = lookup_style(preview_style)
    if style && ((target != :mobile && style.header) || (target == :mobile && style.mobile_header))
      target == :mobile ? style.mobile_header.html_safe : style.header.html_safe
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
      style.ensure_stylesheets_on_disk! if style
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

  def stylesheet_hash(target=:desktop)
    Digest::MD5.hexdigest( target == :mobile ? mobile_stylesheet : stylesheet )
  end

  def cache_fullpath
    "#{Rails.root}/public/#{CACHE_PATH}"
  end

  def ensure_stylesheets_on_disk!
    [[:desktop, 'stylesheet_baked'], [:mobile, 'mobile_stylesheet_baked']].each do |target, baked_attr|
      path = stylesheet_fullpath(target)
      dir = cache_fullpath
      FileUtils.mkdir_p(dir)
      unless File.exists?(path)
        File.open(path, "w") do |f|
          f.puts self.send(baked_attr)
        end
      end
    end
  end

  def stylesheet_filename(target=:desktop)
    target == :desktop ? "/#{self.key}.css" : "/#{target}_#{self.key}.css"
  end

  def stylesheet_fullpath(target=:desktop)
    "#{cache_fullpath}#{stylesheet_filename(target)}"
  end

  def stylesheet_link_tag(target=:desktop)
    return mobile_stylesheet_link_tag if target == :mobile
    return "" unless stylesheet.present?
    return @stylesheet_link_tag if @stylesheet_link_tag
    ensure_stylesheets_on_disk!
    @stylesheet_link_tag = "<link class=\"custom-css\" rel=\"stylesheet\" href=\"/#{CACHE_PATH}#{stylesheet_filename}?#{stylesheet_hash}\" type=\"text/css\" media=\"screen\">"
  end

  def mobile_stylesheet_link_tag
    return "" unless mobile_stylesheet.present?
    return @mobile_stylesheet_link_tag if @mobile_stylesheet_link_tag
    ensure_stylesheets_on_disk!
    @mobile_stylesheet_link_tag = "<link class=\"custom-css\" rel=\"stylesheet\" href=\"/#{CACHE_PATH}#{stylesheet_filename(:mobile)}?#{stylesheet_hash(:mobile)}\" type=\"text/css\" media=\"screen\">"
  end
end

# == Schema Information
#
# Table name: site_customizations
#
#  id                      :integer          not null, primary key
#  name                    :string(255)      not null
#  stylesheet              :text
#  header                  :text
#  position                :integer          not null
#  user_id                 :integer          not null
#  enabled                 :boolean          not null
#  key                     :string(255)      not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  override_default_style  :boolean          default(FALSE), not null
#  stylesheet_baked        :text             default(""), not null
#  mobile_stylesheet       :text
#  mobile_header           :text
#  mobile_stylesheet_baked :text
#
# Indexes
#
#  index_site_customizations_on_key  (key)
#

