# frozen_string_literal: true

class BasicThemeSerializer < ApplicationSerializer
  attributes :id, :name, :description, :created_at, :updated_at, :default, :component

  def include_default?
    object.id == SiteSetting.default_theme_id
  end

  def default
    true
  end
end
