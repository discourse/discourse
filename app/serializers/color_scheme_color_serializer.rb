class ColorSchemeColorSerializer < ApplicationSerializer
  attributes :name, :hex

  def hex
    object.hex # otherwise something crazy is returned
  end
end
