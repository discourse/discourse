class ColorSchemeColorSerializer < ApplicationSerializer
  attributes :name, :hex, :default_hex

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
end
