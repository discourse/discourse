# frozen_string_literal: true

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
    return true if setting.blank?

    host = URI.parse(src).host
    !setting.split("|").include?(host)
  rescue URI::Error
    true
  end

  def self.scheme
    force_https? ? "https" : "http"
  end

  def self.min_redirected_to_top_period(duration)
    ListController.best_period_with_topics_for(duration)
  end

  def self.queue_jobs=(val)
    Discourse.deprecate("queue_jobs is deprecated. Please use Jobs.run_immediately! instead")
    val ? Jobs.run_later! : Jobs.run_immediately!
  end

  def self.email_polling_enabled?
    SiteSetting.manual_polling_enabled? || SiteSetting.pop3_polling_enabled?
  end

  WATCHED_SETTINGS ||= [
    :default_locale,
    :attachment_content_type_blacklist,
    :attachment_filename_blacklist,
    :unicode_username_character_whitelist,
    :markdown_typographer_quotation_marks
  ]

  def self.reset_cached_settings!
    @attachment_content_type_blacklist_regex = nil
    @attachment_filename_blacklist_regex = nil
    @unicode_username_whitelist_regex = nil
  end

  def self.attachment_content_type_blacklist_regex
    @attachment_content_type_blacklist_regex ||= Regexp.union(SiteSetting.attachment_content_type_blacklist.split("|"))
  end

  def self.attachment_filename_blacklist_regex
    @attachment_filename_blacklist_regex ||= Regexp.union(SiteSetting.attachment_filename_blacklist.split("|"))
  end

  def self.unicode_username_character_whitelist_regex
    @unicode_username_whitelist_regex ||= SiteSetting.unicode_username_character_whitelist.present? \
      ? Regexp.new(SiteSetting.unicode_username_character_whitelist) : nil
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
      if SiteSetting.s3_endpoint.blank? || SiteSetting.s3_endpoint.end_with?("amazonaws.com")
        if SiteSetting.Upload.s3_region.start_with?("cn-")
          "//#{bucket}.s3.#{SiteSetting.Upload.s3_region}.amazonaws.com.cn"
        else
          "//#{bucket}.s3.dualstack.#{SiteSetting.Upload.s3_region}.amazonaws.com"
        end
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
  }.each { |client_setting| client_settings << client_setting }

  %i{
    logo
    logo_small
    digest_logo
    mobile_logo
    large_icon
    manifest_icon
    favicon
    apple_touch_icon
    twitter_summary_large_image
    opengraph_image
    push_notifications_icon
  }.each do |setting_name|
    define_singleton_method("site_#{setting_name}_url") do
      if SiteIconManager.respond_to?("#{setting_name}_url")
        return SiteIconManager.public_send("#{setting_name}_url")
      end

      upload = self.public_send(setting_name)
      upload ? full_cdn_url(upload.url) : ''
    end
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
# Indexes
#
#  index_site_settings_on_name  (name) UNIQUE
#
