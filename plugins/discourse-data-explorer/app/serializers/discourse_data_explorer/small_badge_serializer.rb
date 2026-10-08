# frozen_string_literal: true

class DiscourseDataExplorer::SmallBadgeSerializer < ApplicationSerializer
  attributes :id, :name, :display_name, :description, :icon, :image_url
  has_one :badge_type, serializer: BadgeTypeSerializer, embed: :objects
end
