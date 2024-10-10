# frozen_string_literal: true

class AdminPluginSerializer < ApplicationSerializer
  attributes :id,
             :name,
             :about,
             :version,
             :url,
             :admin_route,
             :enabled,
             :enabled_setting,
             :has_settings,
             :has_only_enabled_setting,
             :is_official,
             :is_discourse_owned,
             :label,
             :commit_hash,
             :commit_url,
             :meta_url,
             :authors

  def id
    object.directory_name
  end

  def name
    object.metadata.name
  end

  def about
    object.metadata.about
  end

  def version
    object.metadata.version
  end

  def url
    object.metadata.url
  end

  def authors
    object.metadata.authors
  end

  def enabled
    object.enabled?
  end

  def include_enabled_setting?
    enabled_setting.present?
  end

  def enabled_setting
    object.enabled_site_setting
  end

  def plugin_settings
    @plugin_settings ||= SiteSetting.plugins.select { |_, v| v == id }
  end

  def has_settings
    plugin_settings.values.any?
  end

  def has_only_enabled_setting
    plugin_settings.keys.length == 1 && plugin_settings.keys.first == enabled_setting
  end

  def include_url?
    url.present?
  end

  def admin_route
    object.full_admin_route
  end

  def include_admin_route?
    admin_route.present?
  end

  def is_official
    Plugin::Metadata::OFFICIAL_PLUGINS.include?(object.name)
  end

  def include_label?
    is_discourse_owned
  end

  def label
    return if !is_discourse_owned
    object.metadata.label
  end

  def is_discourse_owned
    object.discourse_owned?
  end

  def commit_hash
    object.commit_hash
  end

  def commit_url
    object.commit_url
  end

  def meta_url
    return if object.metadata.meta_topic_id.blank?
    "https://meta.discourse.org/t/#{object.metadata.meta_topic_id}"
  end
end
