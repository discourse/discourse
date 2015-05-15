class ColorSchemeSerializer < ApplicationSerializer
  attributes :id, :name, :enabled, :is_base
  has_many :colors, serializer: ColorSchemeColorSerializer, embed: :objects

  def base
    object.is_base || false
  end
end
