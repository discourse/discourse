# frozen_string_literal: true

class Reviewable::Audience
  def initialize(topic)
    @topic = topic.dup
    @topic.id = topic.id
    @topic.category = topic.category
  end

  def restricted_by?(destination)
    anonymous = Guardian.new
    return false if anonymous.can_see_topic?(destination, false)
    return true if anonymous.can_see_topic?(@topic, false)
    if !@topic.private_message? && !destination.private_message? &&
         @topic.category_id == destination.category_id
      return false
    end

    readers =
      if @topic.private_message?
        @topic.all_allowed_users
      else
        User.joins(:groups).where(groups: { id: @topic.category.secure_group_ids })
      end
    candidates =
      User
        .where(id: readers.select(:id))
        .or(User.where(id: @topic.user_id))
        .or(User.where(staged: true))
    candidates.find_each.any? do |user|
      guardian = Guardian.new(user)
      guardian.can_see_topic?(@topic, false) && !guardian.can_see_topic?(destination, false)
    end
  end
end
