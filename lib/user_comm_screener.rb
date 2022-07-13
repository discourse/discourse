# frozen_string_literal: true

# There are various ways within Discourse that a user can prevent
# other users communicating with them. The purpose of this class is to
# find which of the target users are ignoring, muting, or preventing
# private messages from the acting user, so we can take alternative
# action (such as raising an error or showing a helpful message) if so.
#
# Users may Mute another user (the actor), which will:
#
#   * Prevent PMs from the actor
#   * Prevent notifications from the actor
#
# Users may Ignore another user (the actor), which will:
#
#   * Do everything that Mute does as well as suppressing content made by
#     the actor (such as posts) from the UI
#
# Users may also either:
#
#   a) disallow PMs from being sent to them or
#   b) disallow PMs except from a certain allowlist of users
#
# A user may have this preference but have no Muted or Ignored users, which
# necessitates the difference between methods in this class.
#
# An important note is that **all of these settings do not apply when the actor
# is a staff member**. So admins and moderators can PM and notify anyone they please.
class UserCommScreener
  attr_reader :acting_user, :preferences

  class UserCommPref
    attr_accessor :username, :is_muting, :is_ignoring, :is_disallowing_all_pms,
      :is_disallowing_pms_from_acting_user

    def initialize(preferences)
      @username = preferences[:username]
      @is_muting = preferences[:is_muting]
      @is_ignoring = preferences[:is_ignoring]
      @is_disallowing_all_pms = preferences[:is_disallowing_all_pms]
      @is_disallowing_pms_from_acting_user = preferences[:is_disallowing_pms_from_acting_user]
    end

    def communication_prevented?
      ignoring_or_muting? || disallowing_pms?
    end

    def ignoring_or_muting?
      is_muting || is_ignoring
    end

    def disallowing_pms?
      is_disallowing_all_pms || is_disallowing_pms_from_acting_user
    end
  end

  UserCommPrefs = Struct.new(:acting_user, :user_preference_map) do
    def acting_user_staff?
      acting_user.staff?
    end

    def usernames
      user_preference_map.values.map(&:username)
    end

    def for_user(username)
      user_preference_map.values.find { |pref| pref.username.downcase == username.downcase }
    end

    def allowing_actor_communication
      return user_preference_map.values if acting_user_staff?
      user_preference_map.reject do |user_id, pref|
        pref.communication_prevented?
      end.values
    end

    def preventing_actor_communication
      return [] if acting_user_staff?
      user_preference_map.select do |user_id, pref|
        pref.communication_prevented?
      end.values
    end

    def ignoring_or_muting?(username)
      return false if acting_user_staff?
      pref = for_user(username)
      pref.present? && pref.ignoring_or_muting?
    end

    def disallowing_pms?(username)
      return false if acting_user_staff?
      pref = for_user(username)
      pref.present? && pref.disallowing_pms?
    end
  end
  private_constant :UserCommPref
  private_constant :UserCommPrefs

  def initialize(acting_user: nil, acting_user_id: nil, target_usernames:)
    raise ArgumentError if acting_user.blank? && acting_user_id.blank?
    @acting_user = acting_user.present? ? acting_user : User.find(acting_user_id)
    @target_users = User.where(
      username_lower: Array.wrap(target_usernames).map(&:downcase)
    ).pluck(:id, :username).to_h
    @preferences = load_preference_map
  end

  ##
  # Users who have preferences are the only ones initially loaded by the query,
  # so implicitly the leftover usernames have no preferences that mute, ignore,
  # or disallow PMs from any other user.
  def allowing_actor_communication
    (preferences.allowing_actor_communication.map(&:username) + usernames_with_no_preference).uniq
  end

  ##
  # Any users who are either ignoring, muting, or disallowing PMs from the actor.
  # Ignoring and muting implicitly ignore PMs which is why they fall under this
  # umbrella as well.
  def preventing_actor_communication
    preferences.preventing_actor_communication.map(&:username)
  end

  ##
  # Whether the user is ignoring or muting the actor, meaning the actor cannot
  # PM or send notifications to this target user.
  def ignoring_or_muting_actor?(username)
    preferences.ignoring_or_muting?(username)
  end

  ##
  # Whether the user is disallowing PMs from the actor specifically or in general,
  # meaning the actor cannot send PMs to this target user. Ignoring or muting
  # implicitly disallows PMs, so we need to take into account those preferences
  # here too.
  def disallowing_pms_from_actor?(username)
    preferences.disallowing_pms?(username) || ignoring_or_muting_actor?(username)
  end

  private

  def usernames_with_no_preference
    @target_users.values - @preferences.usernames
  end

  def load_preference_map
    resolved_user_communication_preferences = {}

    # Since noone can prevent staff communicating with them there is no
    # need to load their preferences.
    if @acting_user.staff?
      return UserCommPrefs.new(acting_user, resolved_user_communication_preferences)
    end

    # Add all users who have muted or ignored the acting user, or have
    # disabled PMs from them or anyone at all.
    user_communication_preferences.each do |user|
      resolved_user_communication_preferences[user.id] = UserCommPref.new(
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
        allowed_pm_user_id: acting_user.id, user_id: user_ids_with_allowed_pms
      ).pluck(:user_id).uniq

      # If not in the list mark them as not accepting communication.
      user_ids_acting_cannot_pm = user_ids_with_allowed_pms - user_ids_acting_can_pm
      user_ids_acting_cannot_pm.each do |user_id|
        if resolved_user_communication_preferences[user_id]
          resolved_user_communication_preferences[user_id].is_disallowing_pms_from_acting_user = true
        else
          resolved_user_communication_preferences[user_id] = UserCommPref.new(
            username: @target_users[user_id],
            is_muting: false,
            is_ignoring: false,
            is_disallowing_all_pms: false,
            is_disallowing_pms_from_acting_user: true
          )
        end
      end
    end

    UserCommPrefs.new(acting_user, resolved_user_communication_preferences)
  end

  def user_communication_preferences
    @user_communication_preferences ||= DB.query(<<~SQL, acting_user_id: acting_user.id, target_user_ids: @target_users.keys)
      SELECT users.id,
      CASE WHEN muted_users.muted_user_id IS NOT NULL THEN true ELSE false END AS is_muting,
      CASE WHEN ignored_users.ignored_user_id IS NOT NULL THEN true ELSE false END AS is_ignoring,
      CASE WHEN user_options.allow_private_messages THEN false ELSE true END AS is_disallowing_all_pms,
      user_options.enable_allowed_pm_users
      FROM users
      LEFT JOIN user_options ON user_options.user_id = users.id
      LEFT JOIN muted_users ON muted_users.user_id = users.id AND muted_users.muted_user_id = :acting_user_id
      LEFT JOIN ignored_users ON ignored_users.user_id = users.id AND ignored_users.ignored_user_id = :acting_user_id
      WHERE users.id IN (:target_user_ids) AND
      (
        NOT user_options.allow_private_messages OR
        user_options.enable_allowed_pm_users OR
        muted_users.user_id IS NOT NULL OR
        ignored_users.user_id IS NOT NULL
      )
    SQL
  end
end
