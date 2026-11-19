# frozen_string_literal: true

class GroupMemberAdder
  LIMIT = 1000

  class EmailsNotAllowed < StandardError
    def initialize(message = nil)
      super(message || I18n.t("groups.errors.cannot_add_emails"))
    end
  end

  class TooManyUsers < StandardError
    def initialize(message = nil)
      super(message || I18n.t("groups.errors.adding_too_many_users", count: LIMIT))
    end
  end

  class AlreadyMembers < StandardError
    attr_reader :usernames

    def initialize(usernames)
      @usernames = usernames
      super(
        I18n.t(
          "groups.errors.member_already_exist",
          username: usernames.sort.join(", "),
          count: usernames.size,
        ),
      )
    end
  end

  def self.add(guardian, group, notify_users: nil, skip_email: false, emails: nil, **selectors)
    new(guardian, group, notify_users:, skip_email:, emails:, **selectors).add
  end

  def initialize(guardian, group, notify_users: nil, skip_email: false, emails: nil, **selectors)
    @guardian = guardian
    @group = group
    @notify_users = notify_users
    @skip_email = skip_email
    @emails = GroupMutations.split_values(emails)
    @selectors = selectors
  end

  def add
    guardian.ensure_can_edit!(group)
    raise EmailsNotAllowed if emails.present? && !guardian.can_invite_to_forum?([group])

    users = GroupMutations.resolve_users(guardian:, **selectors).to_a
    invite_emails = []
    users_by_email = users_for_emails
    emails.each do |email|
      existing_user = users_by_email[Email.downcase(email)]
      existing_user ? users << existing_user : invite_emails << email
    end

    if users.empty? && invite_emails.empty?
      raise Discourse::InvalidParameters.new(I18n.t("groups.errors.usernames_or_emails_required"))
    end
    raise TooManyUsers if users.length > LIMIT

    already_in_group = group.users.where(id: users.map(&:id)).pluck(:username)
    if already_in_group.present? && already_in_group.length == users.length && invite_emails.blank?
      raise AlreadyMembers, already_in_group
    end

    unique_users = users.uniq
    added_user_ids = add_users(unique_users).to_set
    added_users, skipped_users = unique_users.partition { |user| added_user_ids.include?(user.id) }
    invite_emails.each do |email|
      Invite.generate(guardian.user, email:, group_ids: [group.id], skip_email: skip_invite_email?)
    end

    {
      usernames: unique_users.map(&:username),
      added_usernames: added_users.map(&:username),
      skipped_usernames: skipped_users.map(&:username),
      emails: invite_emails,
    }
  end

  private

  attr_reader :guardian, :group, :notify_users, :skip_email, :emails, :selectors

  def users_for_emails
    return {} if emails.blank?

    User
      .with_email(emails.map { Email.downcase(it) })
      .includes(:user_emails)
      .each_with_object({}) do |user, by_email|
        user.user_emails.each { |user_email| by_email[user_email.email.downcase] ||= user }
      end
  end

  def notify?
    notify_users == true
  end

  # An explicit notify_users: false also suppresses the invitation email.
  def skip_invite_email?
    skip_email || (!notify_users.nil? && !notify?)
  end

  def add_users(users)
    added_user_ids = GroupManager.new(group).add(users.map(&:id))
    GroupActionLogger.new(guardian.user, group).bulk_log_add_users_to_group(added_user_ids)
    if notify? && added_user_ids.present?
      Jobs.enqueue(:notify_users_added_to_group, user_ids: added_user_ids, group_id: group.id)
    end
    added_user_ids
  end
end
