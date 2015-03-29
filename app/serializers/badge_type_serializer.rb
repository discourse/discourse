class BadgeTypeSerializer < ApplicationSerializer
  attributes :id, :name, :sort_order

  # change this if/when we allow custom badge types
  # correct for now, though
  def sort_order
    10 - object.id
  end
end
