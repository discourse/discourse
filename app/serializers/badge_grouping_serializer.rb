class BadgeGroupingSerializer < ApplicationSerializer
  attributes :id, :name, :description, :position, :system

  def system
    object.system?
  end
end
