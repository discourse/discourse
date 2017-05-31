class ColorSchemeSerializer < ApplicationSerializer
  attributes :id, :name, :is_base, :base_scheme_id, :theme_id, :theme_name
  has_many :colors, serializer: ColorSchemeColorSerializer, embed: :objects

  def theme_name
    object.theme&.name
  end

  def theme_id
    object.theme&.id
  end
end
