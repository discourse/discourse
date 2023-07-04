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
             :is_official,
             :commit_hash,
             :commit_url

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

  def enabled
    object.enabled?
  end

  def include_enabled_setting?
    enabled_setting.present?
  end

  def enabled_setting
    object.enabled_site_setting
  end

  def has_settings
    SiteSetting.plugins.values.include?(id)
  end

  def include_url?
    url.present?
  end

  def admin_route
    route = object.admin_route
    return unless route

    ret = route.slice(:location, :label)
    ret[:full_location] = "adminPlugins.#{ret[:location]}"
    ret
  end

  def include_admin_route?
    admin_route.present?
  end

  def is_official
    Plugin::Metadata::OFFICIAL_PLUGINS.include?(object.name)
  end

  def commit_hash
    object.commit_hash
  end

  def commit_url
    object.commit_url
  end
end
