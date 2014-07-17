class BadgeSerializer < ApplicationSerializer
  attributes :id, :name, :description, :grant_count, :allow_title, :multiple_grant, :icon, :listable, :enabled, :has_badge
  has_one :badge_type
  has_one :badge_grouping

  def include_has_badge?
    @options[:user_badges]
  end

  def has_badge
    @options[:user_badges].include?(object.id)
  end
end
