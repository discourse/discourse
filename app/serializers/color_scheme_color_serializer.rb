# frozen_string_literal: true

class ColorSchemeColorSerializer < ApplicationSerializer
  attributes :name, :hex, :default_hex, :is_advanced, :dark_hex, :default_dark_hex

  def hex
    object.hex
  end

  def dark_hex
    object.dark_hex || object.hex
  end

  def default_hex
    # return the hex value of the color when based on custom scheme
    # or it is already a base color
    if !object.color_scheme || object.color_scheme.base_scheme_id == "-1"
      object.hex
    else
      object.color_scheme.base_colors[object.name]
    end
  end

  def default_dark_hex
    # TODO(osama) implement this when we add dark mode colors for built-in
    # palettes
    nil
  end

  def is_advanced
    !ColorScheme.base_colors.keys.include?(object.name)
  end
end
