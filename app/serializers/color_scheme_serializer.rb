# frozen_string_literal: true

class ColorSchemeSerializer < ApplicationSerializer
  attributes :id,
             :name,
             :is_base,
             :base_scheme_id,
             :theme_id,
             :theme_name,
             :user_selectable,
             :is_builtin_default
  has_many :colors, serializer: ColorSchemeColorSerializer, embed: :objects

  def theme_name
    object.theme&.name
  end

  def colors
    db_colors = object.colors.sort_by(&:name).index_by(&:name)
    resolved = ColorScheme.sort_colors(object.resolved_colors)
    resolved.map do |name, default|
      db_colors[name] || ColorSchemeColor.new(name: name, hex: default, color_scheme: object)
    end
  end
end
