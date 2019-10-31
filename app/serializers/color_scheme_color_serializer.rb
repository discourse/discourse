# frozen_string_literal: true

class ColorSchemeColorSerializer < ApplicationSerializer
  attributes :name, :hex, :default_hex, :is_advanced

  def hex
    object.hex # otherwise something crazy is returned
  end

  def default_hex
    if object.color_scheme
      object.color_scheme.base_colors[object.name]
    else
      # it is a base color so it is already default
      object.hex
    end
  end

  def is_advanced
    !ColorScheme.base_colors.keys.include?(object.name)
  end
end
