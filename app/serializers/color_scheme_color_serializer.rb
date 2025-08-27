# frozen_string_literal: true

class ColorSchemeColorSerializer < ApplicationSerializer
  attributes :name, :hex, :default_hex, :is_advanced

  def hex
    object.hex
  end

  def default_hex
    # return the hex value of the color when it is already a base color or no base_scheme is set
    if !object.color_scheme || object.color_scheme.base_scheme_id == 0
      object.hex
    else
      object.color_scheme.base_colors[object.name]
    end
  end

  def is_advanced
    !ColorScheme.base_colors.keys.include?(object.name)
  end
end
