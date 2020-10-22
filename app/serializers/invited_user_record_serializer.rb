# frozen_string_literal: true

class InvitedUserRecordSerializer < BasicUserSerializer

  attributes :topics_entered,
             :posts_read_count,
             :last_seen_at,
             :time_read,
             :days_visited,
             :days_since_created

  attr_accessor :invited_by

  def time_read
    object.user_stat.time_read
  end

  def include_time_read?
    can_see_invite_details?
  end

  def days_visited
    object.user_stat.days_visited
  end

  def include_days_visited?
    can_see_invite_details?
  end

  def topics_entered
    object.user_stat.topics_entered
  end

  def include_topics_entered?
    can_see_invite_details?
  end

  def posts_read_count
    object.user_stat.posts_read_count
  end

  def include_posts_read_count?
    can_see_invite_details?
  end

  def days_since_created
    ((Time.now - object.created_at) / 60 / 60 / 24).ceil
  end

  def include_days_since_created
    can_see_invite_details?
  end

  private

  def can_see_invite_details?
    @can_see_invite_details ||= scope.can_see_invite_details?(invited_by)
  end

end
