# frozen_string_literal: true

class ColorSchemeSelectableSerializer < ApplicationSerializer
  attributes :id, :name, :is_dark

  def is_dark
    object.is_dark?
  end
end
