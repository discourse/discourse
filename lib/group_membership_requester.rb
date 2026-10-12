# frozen_string_literal: true

class GroupMembershipRequester
  MAX_NOTIFIED_OWNERS = 20

  class AlreadyRequested < StandardError
    def initialize(message = nil)
      super(message || I18n.t("groups.errors.already_requested_membership"))
    end
  end

  def self.request(guardian, group, reason)
    new(guardian, group, reason).request
  end

  def initialize(guardian, group, reason)
    @guardian = guardian
    @group = group
    @reason = reason
  end

  def request
    user = guardian.user or raise Discourse::NotLoggedIn
    raise Discourse::InvalidAccess if !group.allow_membership_requests?
    raise Discourse::InvalidAccess if group.users.exists?(id: user.id)

    begin
      GroupRequest.create!(group:, user:, reason:)
    rescue ActiveRecord::RecordNotUnique
      raise AlreadyRequested
    end

    PostCreator.new(
      user,
      title: I18n.t("groups.request_membership_pm.title", group_name: group.name),
      raw: reason,
      archetype: Archetype.private_message,
      target_usernames: notified_usernames(user).join(","),
      topic_opts: {
        custom_fields: {
          requested_group_id: group.id,
        },
      },
      skip_validations: true,
    ).create!
  end

  private

  attr_reader :guardian, :group, :reason

  def notified_usernames(user)
    [user.username].concat(
      group
        .users
        .where("group_users.owner")
        .order("users.last_seen_at DESC")
        .limit(MAX_NOTIFIED_OWNERS)
        .pluck("users.username"),
    )
  end
end
