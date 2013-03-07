# Helps us determine whether a topic should be displayed as pinned or not,
# taking into account anonymous users and users who have dismissed it
class PinnedCheck

  def initialize(topic, topic_user=nil)
    @topic, @topic_user = topic, topic_user
  end

  def pinned?

    # If the topic isn't pinned the answer is false
    return false if @topic.pinned_at.blank?

    # If the user is anonymous or hasn't entered the topic, the value is always true
    return true if @topic_user.blank?

    # If the user hasn't cleared the pin, it's true
    return true if @topic_user.cleared_pinned_at.blank?

    # The final check is to see whether the cleared the pin before or after it was last pinned
    @topic_user.cleared_pinned_at < @topic.pinned_at
  end

end