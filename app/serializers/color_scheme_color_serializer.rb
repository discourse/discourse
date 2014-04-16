class ColorSchemeColorSerializer < ApplicationSerializer
  attributes :name, :hex, :opacity

  def hex
    object.hex # otherwise something crazy is returned
  end
end
