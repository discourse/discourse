class InvitedUserSerializer < BasicUserSerializer

  attributes :topics_entered,
             :posts_read_count,
             :last_seen_at,
             :time_read,
             :days_visited,
             :days_since_created

  attr_accessor :invited_by

  def time_read
    AgeWords.age_words(object.user_stat.time_read)
  end

  def days_visited
    object.user_stat.days_visited
  end

  def topics_entered
    object.user_stat.topics_entered
  end

  def posts_read_count
    object.user_stat.posts_read_count
  end

  def days_since_created
    ((Time.now - object.created_at) / 60 / 60 / 24).ceil
  end

  def filter(keys)
    unless scope.can_see_invite_details?(invited_by)
      keys.delete(:time_read)
      keys.delete(:days_visited)
      keys.delete(:topics_entered)
      keys.delete(:posts_read_count)
      keys.delete(:days_since_created)
    end
    super(keys)
  end

end
