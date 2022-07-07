# frozen_string_literal: true

# There are various ways within Discourse that a user can prevent
# other users communicating with them. The purpose of this class is to
# find which of the target users are ignoring, muting, or preventing
# private messages from the acting user, so we can take alternative
# action (such as raising an error or showing a helpful message) if so.
class UserCommunicationDefender
  class UserCommunicationPreference
    attr_accessor :username, :is_muting, :is_ignoring, :is_disallowing_all_pms,
      :is_disallowing_pms_from_acting_user

    def initialize(preferences)
      @username = preferences[:username]
      @is_muting = preferences[:is_muting]
      @is_ignoring = preferences[:is_ignoring]
      @is_disallowing_all_pms = preferences[:is_disallowing_all_pms]
      @is_disallowing_pms_from_acting_user = preferences[:is_disallowing_pms_from_acting_user]
    end

    def communication_allowed?
      !ignoring_or_muting? && !disallowing_pms?
    end

    def ignoring_or_muting?
      is_muting || is_ignoring
    end

    def disallowing_pms?
      is_disallowing_all_pms || is_disallowing_pms_from_acting_user
    end
  end

  UserCommunicationPreferences = Struct.new(:acting_user, :user_preference_map) do
    def acting_user_staff?
      acting_user.staff?
    end

    def for_user(user_id)
      user_preference_map[user_id]
    end

    def each(&block)
      user_preference_map.each do |user_id, pref|
        yield pref
      end
    end
  end

  def initialize(acting_user_id:, target_usernames:)
    @acting_user = User.find(acting_user_id)
    target_usernames = target_usernames.is_a?(Array) ? target_usernames : [target_usernames]
    @target_users = User.where(username_lower: target_usernames).pluck(:id, :username).to_h
  end

  def fetch_user_preferences
    resolved_user_communication_preferences = {}

    # Add all users who have muted or ignored the acting user, or have
    # disabled PMs from them or anyone at all.
    user_communication_preferences.each do |user|
      resolved_user_communication_preferences[user.id] = UserCommunicationPreference.new(
        username: @target_users[user.id],
        is_muting: user.is_muting,
        is_ignoring: user.is_ignoring,
        is_disallowing_all_pms: user.is_disallowing_all_pms,
        is_disallowing_pms_from_acting_user: false
      )
    end

    # If any of the users has allowed_pm_users enabled check to see if the creator
    # is in their list.
    users_with_allowed_pms = user_communication_preferences.select(&:enable_allowed_pm_users)
    if users_with_allowed_pms.any?

      user_ids_with_allowed_pms = users_with_allowed_pms.map(&:id)
      user_ids_acting_can_pm = AllowedPmUser.where(
        allowed_pm_user_id: @acting_user.id, user_id: user_ids_with_allowed_pms
      ).pluck(:user_id).uniq

      # If not in the list mark them as not accepting communication.
      user_ids_acting_cannot_pm = user_ids_with_allowed_pms - user_ids_acting_can_pm
      user_ids_acting_cannot_pm.each do |user_id|
        if resolved_user_communication_preferences[user_id]
          resolved_user_communication_preferences[user_id].is_disallowing_pms_from_acting_user = true
        else
          resolved_user_communication_preferences[user_id] = UserCommunicationPreference.new(
            username: @target_users[user_id],
            is_muting: false,
            is_ignoring: false,
            is_disallowing_all_pms: false,
            is_disallowing_pms_from_acting_user: true
          )
        end
      end
    end

    UserCommunicationPreferences.new(@acting_user, resolved_user_communication_preferences)
  end

  private

  def user_communication_preferences
    @user_communication_preferences ||= DB.query(<<~SQL, acting_user_id: @acting_user.id, target_user_ids: @target_users.keys)
      SELECT users.id,
      CASE WHEN muted_users.muted_user_id IS NOT NULL THEN true ELSE false END AS is_muting,
      CASE WHEN ignored_users.ignored_user_id IS NOT NULL THEN true ELSE false END AS is_ignoring,
      CASE WHEN user_options.allow_private_messages THEN false ELSE true END AS is_disallowing_all_pms,
      user_options.enable_allowed_pm_users
      FROM users
      LEFT JOIN user_options ON user_options.user_id = users.id
      LEFT JOIN muted_users ON muted_users.user_id = users.id AND muted_users.muted_user_id = :acting_user_id
      LEFT JOIN ignored_users ON ignored_users.user_id = users.id AND ignored_users.ignored_user_id = :acting_user_id
      WHERE (user_options.user_id IS NOT NULL AND user_options.user_id IN (:target_user_ids)) AND
      (
        NOT user_options.allow_private_messages OR
        user_options.enable_allowed_pm_users OR
        muted_users.user_id IN (:target_user_ids) OR
        ignored_users.user_id IN (:target_user_ids)
      )
    SQL
  end
end
