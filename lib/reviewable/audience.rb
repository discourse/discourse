# frozen_string_literal: true

class Reviewable::Audience
  def initialize(topic)
    @topic = Topic.instantiate(topic.attributes)
    @topic.category = topic.category
    @message_readers = topic.all_allowed_users if topic.private_message?
  end

  def restricted_by?(destination)
    anonymous = Guardian.new
    return false if anonymous.can_see_topic?(destination, false)
    return true if anonymous.can_see_topic?(@topic, false)

    previous_readers = @message_readers || readers(@topic)
    previous_readers =
      previous_readers.where(admin: false) unless SiteSetting.suppress_secured_categories_from_admin
    previous_readers.where.not(id: readers(destination).select(:id)).exists?
  end

  private

  def readers(topic)
    return topic.all_allowed_users if topic.private_message?

    category = topic.category
    users =
      if category.read_restricted?
        User.where(id: GroupUser.where(group_id: category.secure_group_ids).select(:user_id))
      else
        User.all
      end
    if category.read_restricted? && category.email_in.present? && category.email_in_allow_strangers
      users = users.or(User.where(id: topic.user_id, staged: true))
    end
    return users unless topic.shared_draft

    groups = SiteSetting.shared_drafts_allowed_groups_map
    return users if groups.include?(Group::AUTO_GROUPS[:logged_in_users])
    if groups.include?(Group::AUTO_GROUPS[:everyone]) &&
         !SiteSetting.granular_anonymous_and_logged_in_groups_permissions
      return users
    end
    users.where(id: GroupUser.where(group_id: groups).select(:user_id))
  end
end
