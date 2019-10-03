# frozen_string_literal: true

class Jobs::TopicActionConverter < ::Jobs::Base

  # Re-creating all the user actions could be very slow, so let's do it in a job
  # to avoid a N+1 query on a front facing operation.
  def execute(args)
    topic = Topic.find_by(id: args[:topic_id])
    return if topic.blank?

    UserAction.where(
      target_topic_id: topic.id,
      action_type: [UserAction::GOT_PRIVATE_MESSAGE, UserAction::NEW_PRIVATE_MESSAGE]).find_each do |ua|
        UserAction.remove_action!(ua.attributes.symbolize_keys.slice(:action_type, :user_id, :acting_user_id, :target_topic_id, :target_post_id))
      end
    topic.posts.each { |post| UserActionManager.post_created(post) }
    UserActionManager.topic_created(topic)
  end

end
