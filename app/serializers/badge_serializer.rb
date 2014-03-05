class BadgeSerializer < ApplicationSerializer
  attributes :id, :name, :description

  has_one :badge_type
end
