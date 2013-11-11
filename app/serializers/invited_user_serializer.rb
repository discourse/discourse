class InvitedUserSerializer < BasicUserSerializer

  attributes :topics_entered,
             :posts_read_count,
             :last_seen_at,
             :time_read,
             :days_visited,
             :days_since_created

  def time_read
    return nil if object.time_read.blank?
    AgeWords.age_words(object.time_read)
  end

  def days_since_created
    ((Time.now - object.created_at) / 60 / 60 / 24).ceil
  end

end
