# frozen_string_literal: true

class AdminPluginSerializer < ApplicationSerializer
  attributes :id,
             :name,
             :version,
             :url,
             :admin_route,
             :enabled,
             :enabled_setting,
             :is_official,
             :enabled_setting_filter

  def id
    object.metadata.name
  end

  def name
    object.metadata.name
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

  def include_enabled_setting_filter?
    object.enabled_site_setting_filter.present?
  end

  def enabled_setting_filter
    object.enabled_site_setting_filter
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
end
