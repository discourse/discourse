require 'site_setting_extension'
require_dependency 'site_settings/yaml_loader'

class SiteSetting < ActiveRecord::Base
  extend SiteSettingExtension

  validates_presence_of :name
  validates_presence_of :data_type

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

  Dir[File.join(Rails.root, "plugins", "*", "config", "settings.yml")].each do |file|
    load_settings(file)
  end


  def self.call_discourse_hub?
    self.enforce_global_nicknames? && self.discourse_org_access_key.present?
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

  def self.authorized_uploads
    authorized_extensions.tr(" ", "")
                         .split("|")
                         .map { |extension| (extension.start_with?(".") ? extension[1..-1] : extension).gsub(".", "\.") }
  end

  def self.authorized_upload?(file)
    authorized_uploads.count > 0 && file.original_filename =~ /\.(#{authorized_uploads.join("|")})$/i
  end

  def self.images
    @images ||= Set.new ["jpg", "jpeg", "png", "gif", "tif", "tiff", "bmp"]
  end

  def self.authorized_images
    authorized_uploads.select { |extension| images.include?(extension) }
  end

  def self.authorized_image?(file)
    authorized_images.count > 0 && file.original_filename =~ /\.(#{authorized_images.join("|")})$/i
  end

  def self.scheme
    use_ssl? ? "https" : "http"
  end

end

# == Schema Information
#
# Table name: site_settings
#
#  id         :integer          not null, primary key
#  name       :string(255)      not null
#  data_type  :integer          not null
#  value      :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

