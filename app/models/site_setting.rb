require 'site_setting_extension'
require_dependency 'global_path'
require_dependency 'site_settings/yaml_loader'

class SiteSetting < ActiveRecord::Base
  extend GlobalPath
  extend SiteSettingExtension

  validates_presence_of :name
  validates_presence_of :data_type

  after_save do |site_setting|
    DiscourseEvent.trigger(:site_setting_saved, site_setting)
    true
  end

  def self.load_settings(file)
    SiteSettings::YamlLoader.new(file).load do |category, name, default, opts|
      setting(name, default, opts.merge(category: category))
    end
  end

  load_settings(File.join(Rails.root, 'config', 'site_settings.yml'))

  unless Rails.env.test? && ENV['LOAD_PLUGINS'] != "1"
    Dir[File.join(Rails.root, "plugins", "*", "config", "settings.yml")].each do |file|
      load_settings(file)
    end
  end

  setup_deprecated_methods
  client_settings << :available_locales

  def self.available_locales
    LocaleSiteSetting.values.to_json
  end

  def self.topic_title_length
    min_topic_title_length..max_topic_title_length
  end

  def self.private_message_title_length
    min_personal_message_title_length..max_topic_title_length
  end

  def self.post_length
    min_post_length..max_post_length
  end

  def self.first_post_length
    min_first_post_length..max_post_length
  end

  def self.private_message_post_length
    min_personal_message_post_length..max_post_length
  end

  def self.top_menu_items
    top_menu.split('|').map { |menu_item| TopMenuItem.new(menu_item) }
  end

  def self.homepage
    top_menu_items[0].name
  end

  def self.anonymous_menu_items
    @anonymous_menu_items ||= Set.new Discourse.anonymous_filters.map(&:to_s)
  end

  def self.anonymous_homepage
    top_menu_items.map { |item| item.name }
      .select { |item| anonymous_menu_items.include?(item) }
      .first
  end

  def self.should_download_images?(src)
    setting = disabled_image_download_domains
    return true unless setting.present?

    host = URI.parse(src).host
    return !(setting.split('|').include?(host))
  rescue URI::Error
    return true
  end

  def self.scheme
    force_https? ? "https" : "http"
  end

  def self.default_categories_selected
    [
      SiteSetting.default_categories_watching.split("|"),
      SiteSetting.default_categories_tracking.split("|"),
      SiteSetting.default_categories_muted.split("|"),
      SiteSetting.default_categories_watching_first_post.split("|")
    ].flatten.to_set
  end

  def self.min_redirected_to_top_period(duration)
    period = ListController.best_period_with_topics_for(duration)
    return period if period

    # not enough topics
    nil
  end

  def self.email_polling_enabled?
    SiteSetting.manual_polling_enabled? || SiteSetting.pop3_polling_enabled?
  end

  def self.attachment_content_type_blacklist_regex
    @attachment_content_type_blacklist_regex ||= Regexp.union(SiteSetting.attachment_content_type_blacklist.split("|"))
  end

  def self.attachment_filename_blacklist_regex
    @attachment_filename_blacklist_regex ||= Regexp.union(SiteSetting.attachment_filename_blacklist.split("|"))
  end

  # helpers for getting s3 settings that fallback to global
  class Upload
    def self.s3_cdn_url
      SiteSetting.enable_s3_uploads ? SiteSetting.s3_cdn_url : GlobalSetting.s3_cdn_url
    end

    def self.s3_region
      SiteSetting.enable_s3_uploads ? SiteSetting.s3_region : GlobalSetting.s3_region
    end

    def self.s3_upload_bucket
      SiteSetting.enable_s3_uploads ? SiteSetting.s3_upload_bucket : GlobalSetting.s3_bucket
    end

    def self.s3_endpoint
      SiteSetting.enable_s3_uploads ? SiteSetting.s3_endpoint : GlobalSetting.s3_endpoint
    end

    def self.s3_force_path_style
      SiteSetting.enable_s3_uploads ? SiteSetting.s3_force_path_style : GlobalSetting.s3_force_path_style
    end

    def self.enable_s3_uploads
      SiteSetting.enable_s3_uploads || GlobalSetting.use_s3?
    end

    def self.s3_base_url
      path = self.s3_upload_bucket.split("/", 2)[1]
      "#{self.absolute_base_url}#{path ? '/' + path : ''}"
    end

    def self.absolute_base_url
      url_basename = SiteSetting.s3_endpoint.split('/')[-1]
      bucket = SiteSetting.enable_s3_uploads ? Discourse.store.s3_bucket_name : GlobalSetting.s3_bucket_name

      # cf. http://docs.aws.amazon.com/general/latest/gr/rande.html#s3_region
      if SiteSetting.s3_endpoint == "https://s3.amazonaws.com"
        if SiteSetting.Upload.s3_region.start_with?("cn-")
          "//#{bucket}.s3.#{SiteSetting.Upload.s3_region}.amazonaws.com.cn"
        else
          "//#{bucket}.s3.dualstack.#{SiteSetting.Upload.s3_region}.amazonaws.com"
        end
      elsif SiteSetting.s3_force_path_style
        "//#{url_basename}/#{bucket}"
      else
        "//#{bucket}.#{url_basename}"
      end
    end
  end

  def self.Upload
    SiteSetting::Upload
  end

  %i{
    site_logo_url
    site_logo_small_url
    site_mobile_logo_url
    site_favicon_url
    site_home_logo_url
  }.each { |client_setting| client_settings << client_setting }

  def self.site_home_logo_url
    upload = SiteSetting.logo

    if SiteSetting.defaults.get(:title) != SiteSetting.title && !upload
      ''
    else
      full_cdn_url(upload ? upload.url : '/images/d-logo-sketch.png')
    end
  end

  def self.site_logo_url
    upload = self.logo
    upload ? full_cdn_url(upload.url) : self.logo_url(warn: false)
  end

  def self.site_logo_small_url
    upload = self.logo_small
    upload ? full_cdn_url(upload.url) : self.logo_small_url(warn: false)
  end

  def self.site_digest_logo_url
    upload = self.digest_logo
    upload ? full_cdn_url(upload.url) : self.digest_logo_url(warn: false)
  end

  def self.site_mobile_logo_url
    upload = self.mobile_logo
    upload ? full_cdn_url(upload.url) : self.mobile_logo_url(warn: false)
  end

  def self.site_large_icon_url
    upload = self.large_icon
    upload ? full_cdn_url(upload.url) : self.large_icon_url(warn: false)
  end

  def self.site_favicon_url
    upload = self.favicon
    upload ? full_cdn_url(upload.url) : self.favicon_url(warn: false)
  end

  def self.site_apple_touch_icon_url
    upload = self.apple_touch_icon
    upload ? full_cdn_url(upload.url) : self.apple_touch_icon_url(warn: false)
  end

  def self.opengraph_image_url
    upload = self.opengraph_image
    upload ? full_cdn_url(upload.url) : self.default_opengraph_image_url(warn: false)
  end

  def self.site_twitter_summary_large_image_url
    self.twitter_summary_large_image&.url ||
      self.twitter_summary_large_image_url(warn: false)
  end

  def self.site_push_notifications_icon_url
    SiteSetting.push_notifications_icon&.url ||
      SiteSetting.push_notifications_icon_url(warn: false)
  end

  def self.shared_drafts_enabled?
    c = SiteSetting.shared_drafts_category
    c.present? && c.to_i != SiteSetting.uncategorized_category_id.to_i
  end

end

# == Schema Information
#
# Table name: site_settings
#
#  id         :integer          not null, primary key
#  name       :string           not null
#  data_type  :integer          not null
#  value      :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
