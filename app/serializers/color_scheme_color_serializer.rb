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
    if object.color_scheme
      object.color_scheme.base_colors[object.name]
    else
      # it is a base color so it is already default
      object.hex
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
