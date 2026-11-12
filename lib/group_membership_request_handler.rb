# frozen_string_literal: true

class GroupMembershipRequestHandler
  def self.handle(guardian, group, user, accept:)
    new(guardian, group, user, accept:).handle
  end

  def initialize(guardian, group, user, accept:)
    @guardian = guardian
    @group = group
    @user = user
    @accept = accept
  end

  def handle
    guardian.ensure_can_edit!(group)
    request_topic = accept ? find_request_topic : nil

    Group.transaction do
      if accept
        group.add(user)
        GroupActionLogger.new(guardian.user, group).log_add_user_to_group(user)
      end

      GroupRequest.where(group_id: group.id, user_id: user.id).delete_all
    end

    reply_to_request(request_topic) if accept && request_topic
    { accepted: accept }
  end

  private

  attr_reader :guardian, :group, :user, :accept

  def find_request_topic
    Topic.find_by(
      title:
        I18n.t(
          "groups.request_membership_pm.title",
          group_name: group.name,
          locale: user.effective_locale,
        ),
      archetype: Archetype.private_message,
      user_id: user.id,
    )
  end

  def reply_to_request(request_topic)
    PostCreator.new(
      guardian.user,
      post_type: Post.types[:regular],
      topic_id: request_topic.id,
      raw:
        I18n.t(
          "groups.request_accepted_pm.body",
          group_name: group.name,
          locale: user.effective_locale,
        ),
      reply_to_post_number: 1,
      target_usernames: user.username,
      skip_validations: true,
    ).create!
  end
end
