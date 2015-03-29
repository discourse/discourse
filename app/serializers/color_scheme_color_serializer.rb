class ColorSchemeColorSerializer < ApplicationSerializer
  attributes :name, :hex, :default_hex

  def hex
    object.hex # otherwise something crazy is returned
  end

  def default_hex
    ColorScheme.base_colors[object.name]
  end
end
