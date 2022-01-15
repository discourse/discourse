# frozen_string_literal: true

class SiteSetting < ActiveRecord::Base
  extend GlobalPath
  extend SiteSettingExtension

  validates_presence_of :name
  validates_presence_of :data_type

  def self.load_settings(file, plugin: nil)
    SiteSettings::YamlLoader.new(file).load do |category, name, default, opts|
      setting(name, default, opts.merge(category: category, plugin: plugin))
    end
  end

  load_settings(File.join(Rails.root, 'config', 'site_settings.yml'))

  if GlobalSetting.load_plugins?
    Dir[File.join(Rails.root, "plugins", "*", "config", "settings.yml")].each do |file|
      load_settings(file, plugin: file.split("/")[-3])
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
    Discourse.deprecate("queue_jobs is deprecated. Please use Jobs.run_immediately! instead", drop_from: '2.9.0')
    val ? Jobs.run_later! : Jobs.run_immediately!
  end

  def self.email_polling_enabled?
    SiteSetting.manual_polling_enabled? || SiteSetting.pop3_polling_enabled?
  end

  WATCHED_SETTINGS ||= [
    :default_locale,
    :blocked_attachment_content_types,
    :blocked_attachment_filenames,
    :allowed_unicode_username_characters,
    :markdown_typographer_quotation_marks
  ]

  def self.reset_cached_settings!
    @blocked_attachment_content_types_regex = nil
    @blocked_attachment_filenames_regex = nil
    @allowed_unicode_username_regex = nil
  end

  def self.blocked_attachment_content_types_regex
    @blocked_attachment_content_types_regex ||= Regexp.union(SiteSetting.blocked_attachment_content_types.split("|"))
  end

  def self.blocked_attachment_filenames_regex
    @blocked_attachment_filenames_regex ||= Regexp.union(SiteSetting.blocked_attachment_filenames.split("|"))
  end

  def self.allowed_unicode_username_characters_regex
    @allowed_unicode_username_regex ||= SiteSetting.allowed_unicode_username_characters.present? \
      ? Regexp.new(SiteSetting.allowed_unicode_username_characters) : nil
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

  def self.require_invite_code
    invite_code.present?
  end
  client_settings << :require_invite_code

  %i{
    site_logo_url
    site_logo_small_url
    site_mobile_logo_url
    site_favicon_url
    site_logo_dark_url
    site_logo_small_dark_url
    site_mobile_logo_dark_url
  }.each { |client_setting| client_settings << client_setting }

  %i{
    logo
    logo_small
    digest_logo
    mobile_logo
    logo_dark
    logo_small_dark
    mobile_logo_dark
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

  ALLOWLIST_DEPRECATED_SITE_SETTINGS = {
    'email_domains_blacklist': 'blocked_email_domains',
    'email_domains_whitelist': 'allowed_email_domains',
    'unicode_username_character_whitelist': 'allowed_unicode_username_characters',
    'user_website_domains_whitelist': 'allowed_user_website_domains',
    'whitelisted_link_domains': 'allowed_link_domains',
    'embed_whitelist_selector': 'allowed_embed_selectors',
    'auto_generated_whitelist': 'auto_generated_allowlist',
    'attachment_content_type_blacklist': 'blocked_attachment_content_types',
    'attachment_filename_blacklist': 'blocked_attachment_filenames',
    'use_admin_ip_whitelist': 'use_admin_ip_allowlist',
    'blacklist_ip_blocks': 'blocked_ip_blocks',
    'whitelist_internal_hosts': 'allowed_internal_hosts',
    'whitelisted_crawler_user_agents': 'allowed_crawler_user_agents',
    'blacklisted_crawler_user_agents': 'blocked_crawler_user_agents',
    'onebox_domains_blacklist': 'blocked_onebox_domains',
    'inline_onebox_domains_whitelist': 'allowed_inline_onebox_domains',
    'white_listed_spam_host_domains': 'allowed_spam_host_domains',
    'embed_blacklist_selector': 'blocked_embed_selectors',
    'embed_classname_whitelist': 'allowed_embed_classnames',
  }

  ALLOWLIST_DEPRECATED_SITE_SETTINGS.each_pair do |old_method, new_method|
    self.define_singleton_method(old_method) do
      Discourse.deprecate("#{old_method.to_s} is deprecated, use the #{new_method.to_s}.", drop_from: "2.6", raise_error: true)
      send(new_method)
    end
    self.define_singleton_method("#{old_method}=") do |args|
      Discourse.deprecate("#{old_method.to_s} is deprecated, use the #{new_method.to_s}.", drop_from: "2.6", raise_error: true)
      send("#{new_method}=", args)
    end
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
