class ColorSchemeSerializer < ApplicationSerializer
  attributes :id, :name, :is_base, :base_scheme_id
  has_many :colors, serializer: ColorSchemeColorSerializer, embed: :objects
end
