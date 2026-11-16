# frozen_string_literal: true

class BasicThemeSerializer < ApplicationSerializer
  attributes :id, :name, :description, :created_at, :updated_at, :default, :component

  attributes :managed_component

  def include_managed_component?
    object.managed_component?
  end

  def managed_component
    true
  end

  def include_default?
    object.id == SiteSetting.default_theme_id
  end

  def default
    true
  end
end
