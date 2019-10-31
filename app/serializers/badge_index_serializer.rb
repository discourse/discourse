# frozen_string_literal: true

class BadgeIndexSerializer < BadgeSerializer
  attributes :has_badge
  has_one :badge_grouping

  def include_has_badge?
    @options[:user_badges]
  end

  def has_badge
    @options[:user_badges].include?(object.id)
  end

end
