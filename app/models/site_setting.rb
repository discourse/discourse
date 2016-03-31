require 'site_setting_extension'
require_dependency 'site_settings/yaml_loader'

class SiteSetting < ActiveRecord::Base
  extend SiteSettingExtension

  validates_presence_of :name
  validates_presence_of :data_type

  after_save do |site_setting|
    DiscourseEvent.trigger(:site_setting_saved, site_setting)
    true
  end

  def self.load_settings(file)
    SiteSettings::YamlLoader.new(file).load do |category, name, default, opts|
      if opts.delete(:client)
        client_setting(name, default, opts.merge(category: category))
      else
        setting(name, default, opts.merge(category: category))
      end
    end
  end

  load_settings(File.join(Rails.root, 'config', 'site_settings.yml'))

  unless Rails.env.test? && ENV['LOAD_PLUGINS'] != "1"
    Dir[File.join(Rails.root, "plugins", "*", "config", "settings.yml")].each do |file|
      load_settings(file)
    end
  end

  client_settings << :available_locales

  def self.available_locales
    LocaleSiteSetting.values.map{ |e| e[:value] }.join('|')
  end

  def self.topic_title_length
    min_topic_title_length..max_topic_title_length
  end

  def self.private_message_title_length
    min_private_message_title_length..max_topic_title_length
  end

  def self.post_length
    min_post_length..max_post_length
  end

  def self.first_post_length
    min_first_post_length..max_post_length
  end

  def self.private_message_post_length
    min_private_message_post_length..max_post_length
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
  rescue URI::InvalidURIError
    return true
  end

  def self.scheme
    use_https? ? "https" : "http"
  end

  def self.default_categories_selected
    [
      SiteSetting.default_categories_watching.split("|"),
      SiteSetting.default_categories_tracking.split("|"),
      SiteSetting.default_categories_muted.split("|"),
    ].flatten.to_set
  end

  def self.min_redirected_to_top_period
    TopTopic.sorted_periods.each do |p|
      period = p[0]
      return period if TopTopic.topics_per_period(period) >= SiteSetting.topics_per_period_in_top_page
    end
    # not enough topics
    nil
  end

  def self.email_polling_enabled?
    SiteSetting.manual_polling_enabled? || SiteSetting.pop3_polling_enabled?
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
