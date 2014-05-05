class ColorSchemeSerializer < ApplicationSerializer
  attributes :id, :name, :enabled, :can_edit

  has_many :colors, serializer: ColorSchemeColorSerializer, embed: :objects

  def can_edit
    object.can_edit?
  end
end