# this class is used to mirror unread and new status back to end users
# in JavaScript there is a mirror class that is kept in-sync using the mssage bus
# the allows end users to always know which topics have unread posts in them
# and which topics are new

class UserTrackingState

  CHANNEL = "/user-tracking"

  MessageBus.client_filter(CHANNEL) do |user_id, message|
    if user_id
      UserTrackingState.new(User.find(user_id)).filter(message)
    else
      nil
    end
  end

  def self.trigger_change(topic_id, post_number, user_id=nil)
    MessageBus.publish(CHANNEL, "CHANGE", user_ids: [user_id].compact)
  end

  def initialize(user)
    @user = user
    @query = TopicQuery.new(@user)
  end

  def new_list
    @query
      .new_results(limit: false)
      .select(topics: [:id, :created_at])
      .map{|t| [t.id, t.created_at]}
  end

  def unread_list
    []
  end

  def filter(message)
  end

end
