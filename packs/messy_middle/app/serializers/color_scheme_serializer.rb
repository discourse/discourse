# frozen_string_literal: true

class ColorSchemeSerializer < ApplicationSerializer
  attributes :id, :name, :is_base, :base_scheme_id, :theme_id, :theme_name, :user_selectable
  has_many :colors, serializer: ColorSchemeColorSerializer, embed: :objects

  def theme_name
    object.theme&.name
  end

  def theme_id
    object.theme&.id
  end

  def colors
    db_colors = object.colors.index_by(&:name)
    object.resolved_colors.map do |name, default|
      db_colors[name] || ColorSchemeColor.new(name: name, hex: default, color_scheme: object)
    end
  end
end
