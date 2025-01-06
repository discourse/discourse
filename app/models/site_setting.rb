# frozen_string_literal: true

class SiteSetting < ActiveRecord::Base
  VALID_AREAS = %w[about embedding emojis flags fonts legal notifications permalinks]

  extend GlobalPath
  extend SiteSettingExtension

  has_many :upload_references, as: :target, dependent: :destroy

  validates_presence_of :name
  validates_presence_of :data_type

  after_save do
    if saved_change_to_value?
      if self.data_type == SiteSettings::TypeSupervisor.types[:upload]
        UploadReference.ensure_exist!(upload_ids: [self.value], target: self)
      elsif self.data_type == SiteSettings::TypeSupervisor.types[:uploaded_image_list]
        upload_ids = self.value.split("|").compact.uniq
        UploadReference.ensure_exist!(upload_ids: upload_ids, target: self)
      end
    end
  end

  load_settings(File.join(Rails.root, "config", "site_settings.yml"))

  if Rails.env.test?
    SAMPLE_TEST_PLUGIN =
      Plugin::Instance.new(
        Plugin::Metadata.new.tap { |metadata| metadata.name = "discourse-sample-plugin" },
      )

    Discourse.plugins_by_name[SAMPLE_TEST_PLUGIN.name] = SAMPLE_TEST_PLUGIN

    load_settings(
      File.join(Rails.root, "spec", "support", "sample_plugin_site_settings.yml"),
      plugin: SAMPLE_TEST_PLUGIN.name,
    )
  end

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
    top_menu_map.map { |menu_item| TopMenuItem.new(menu_item) }
  end

  def self.homepage
    top_menu_items[0].name
  end

  def self.anonymous_menu_items
    @anonymous_menu_items ||= Set.new Discourse.anonymous_filters.map(&:to_s)
  end

  def self.anonymous_homepage
    top_menu_items
      .map { |item| item.name }
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

  def self.email_polling_enabled?
    SiteSetting.manual_polling_enabled? || SiteSetting.pop3_polling_enabled? ||
      DiscoursePluginRegistry.mail_pollers.any?(&:enabled?)
  end

  def self.blocked_attachment_content_types_regex
    current_db = RailsMultisite::ConnectionManagement.current_db

    @blocked_attachment_content_types_regex ||= {}
    @blocked_attachment_content_types_regex[current_db] ||= begin
      Regexp.union(SiteSetting.blocked_attachment_content_types.split("|"))
    end
  end

  def self.blocked_attachment_filenames_regex
    current_db = RailsMultisite::ConnectionManagement.current_db

    @blocked_attachment_filenames_regex ||= {}
    @blocked_attachment_filenames_regex[current_db] ||= begin
      Regexp.union(SiteSetting.blocked_attachment_filenames.split("|"))
    end
  end

  def self.allowed_unicode_username_characters_regex
    current_db = RailsMultisite::ConnectionManagement.current_db

    @allowed_unicode_username_regex ||= {}
    @allowed_unicode_username_regex[current_db] ||= begin
      if SiteSetting.allowed_unicode_username_characters.present?
        Regexp.new(SiteSetting.allowed_unicode_username_characters)
      end
    end
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

    def self.enable_s3_transfer_acceleration
      if SiteSetting.enable_s3_uploads
        SiteSetting.enable_s3_transfer_acceleration
      else
        GlobalSetting.enable_s3_transfer_acceleration
      end
    end

    def self.use_dualstack_endpoint
      return false if !SiteSetting.Upload.enable_s3_uploads
      return false if SiteSetting.Upload.s3_endpoint.present?
      !SiteSetting.Upload.s3_region.start_with?("cn-")
    end

    def self.enable_s3_uploads
      SiteSetting.enable_s3_uploads || GlobalSetting.use_s3?
    end

    def self.s3_base_url
      path = self.s3_upload_bucket.split("/", 2)[1]
      "#{self.absolute_base_url}#{path ? "/" + path : ""}"
    end

    def self.absolute_base_url
      url_basename = SiteSetting.s3_endpoint.split("/")[-1]
      bucket =
        (
          if SiteSetting.enable_s3_uploads
            Discourse.store.s3_bucket_name
          else
            GlobalSetting.s3_bucket_name
          end
        )

      # cf. http://docs.aws.amazon.com/general/latest/gr/rande.html#s3_region
      if SiteSetting.s3_endpoint.blank? || SiteSetting.s3_endpoint.end_with?("amazonaws.com")
        if SiteSetting.Upload.use_dualstack_endpoint
          "//#{bucket}.s3.dualstack.#{SiteSetting.Upload.s3_region}.amazonaws.com"
        else
          "//#{bucket}.s3.#{SiteSetting.Upload.s3_region}.amazonaws.com.cn"
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

  %i[
    site_logo_url
    site_logo_small_url
    site_mobile_logo_url
    site_favicon_url
    site_logo_dark_url
    site_logo_small_dark_url
    site_mobile_logo_dark_url
  ].each { |client_setting| client_settings << client_setting }

  %i[
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
  ].each do |setting_name|
    define_singleton_method("site_#{setting_name}_url") do
      if SiteIconManager.respond_to?("#{setting_name}_url")
        return SiteIconManager.public_send("#{setting_name}_url")
      end

      upload = self.public_send(setting_name)
      upload ? full_cdn_url(upload.url) : ""
    end
  end

  def self.shared_drafts_enabled?
    c = SiteSetting.shared_drafts_category
    c.present? && c.to_i != SiteSetting.uncategorized_category_id.to_i
  end

  protected

  def self.clear_cache!
    super

    @blocked_attachment_content_types_regex = nil
    @blocked_attachment_filenames_regex = nil
    @allowed_unicode_username_regex = nil
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
