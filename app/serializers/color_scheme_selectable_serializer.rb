# frozen_string_literal: true

class ColorSchemeSelectableSerializer < ApplicationSerializer
  attributes :id, :name, :is_dark, :theme_id, :colors
  has_many :colors, serializer: ColorSchemeColorSerializer, embed: :objects

  def is_dark
    object.is_dark?
  end
end
