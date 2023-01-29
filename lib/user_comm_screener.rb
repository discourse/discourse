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
#
# The secondary usage of this class is to determine which users the actor themselves
# are muting, ignoring, or preventing private messages from. This is useful when
# wanting to alert the actor to these users in the UI in various ways, or prevent
# the actor from communicating with users they prefer not to talk with.
class UserCommScreener
  attr_reader :acting_user, :preferences

  class UserCommPref
    attr_accessor :user_id,
                  :is_muting,
                  :is_ignoring,
                  :is_disallowing_all_pms,
                  :is_disallowing_pms_from_acting_user

    def initialize(preferences)
      @user_id = preferences[:user_id]
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

  UserCommPrefs =
    Struct.new(:acting_user, :user_preference_map) do
      def acting_user_staff?
        acting_user.staff?
      end

      def user_ids
        user_preference_map.keys
      end

      def for_user(user_id)
        user_preference_map[user_id]
      end

      def allowing_actor_communication
        return user_preference_map.values if acting_user_staff?
        user_preference_map.reject { |user_id, pref| pref.communication_prevented? }.values
      end

      def preventing_actor_communication
        return [] if acting_user_staff?
        user_preference_map.select { |user_id, pref| pref.communication_prevented? }.values
      end

      def ignoring_or_muting?(user_id)
        return false if acting_user_staff?
        pref = for_user(user_id)
        pref.present? && pref.ignoring_or_muting?
      end

      def disallowing_pms?(user_id)
        return false if acting_user_staff?
        pref = for_user(user_id)
        pref.present? && pref.disallowing_pms?
      end
    end
  private_constant :UserCommPref
  private_constant :UserCommPrefs

  def initialize(acting_user: nil, acting_user_id: nil, target_user_ids:)
    raise ArgumentError if acting_user.blank? && acting_user_id.blank?
    @acting_user = acting_user.present? ? acting_user : User.find(acting_user_id)
    target_user_ids = Array.wrap(target_user_ids) - [@acting_user.id]
    @target_users = User.where(id: target_user_ids).pluck(:id, :username).to_h
    @preferences = load_preference_map
  end

  ##
  # Users who have preferences are the only ones initially loaded by the query,
  # so implicitly the leftover users have no preferences that mute, ignore,
  # or disallow PMs from any other user.
  def allowing_actor_communication
    (preferences.allowing_actor_communication.map(&:user_id) + users_with_no_preference).uniq
  end

  ##
  # Any users who are either ignoring, muting, or disallowing PMs from the actor.
  # Ignoring and muting implicitly ignore PMs which is why they fall under this
  # umbrella as well.
  def preventing_actor_communication
    preferences.preventing_actor_communication.map(&:user_id)
  end

  ##
  # Whether the user is ignoring or muting the actor, meaning the actor cannot
  # PM or send notifications to this target user.
  def ignoring_or_muting_actor?(user_id)
    validate_user_id!(user_id)
    preferences.ignoring_or_muting?(user_id)
  end

  ##
  # Whether the user is disallowing PMs from the actor specifically or in general,
  # meaning the actor cannot send PMs to this target user. Ignoring or muting
  # implicitly disallows PMs, so we need to take into account those preferences
  # here too.
  def disallowing_pms_from_actor?(user_id)
    validate_user_id!(user_id)
    preferences.disallowing_pms?(user_id) || ignoring_or_muting_actor?(user_id)
  end

  def actor_allowing_communication
    @target_users.keys - actor_preventing_communication
  end

  def actor_preventing_communication
    (
      actor_preferences[:ignoring] + actor_preferences[:muting] +
        actor_preferences[:disallowed_pms_from]
    ).uniq
  end

  ##
  # The actor methods below are more fine-grained than the user ones,
  # since we may want to display more detailed messages to the actor about
  # their preferences than we do when we are informing the actor that
  # they cannot communicate with certain users.
  #
  # In this spirit, actor_disallowing_pms? is intentionally different from
  # disallowing_pms_from_actor? above.

  def actor_ignoring?(user_id)
    validate_user_id!(user_id)
    actor_preferences[:ignoring].include?(user_id)
  end

  def actor_muting?(user_id)
    validate_user_id!(user_id)
    actor_preferences[:muting].include?(user_id)
  end

  def actor_disallowing_pms?(user_id)
    validate_user_id!(user_id)
    return true if actor_disallowing_all_pms?
    return false if !acting_user.user_option.enable_allowed_pm_users
    actor_preferences[:disallowed_pms_from].include?(user_id)
  end

  def actor_disallowing_all_pms?
    !acting_user.user_option.allow_private_messages
  end

  private

  def users_with_no_preference
    @target_users.keys - @preferences.user_ids
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
        user_id: user.id,
        is_muting: user.is_muting,
        is_ignoring: user.is_ignoring,
        is_disallowing_all_pms: user.is_disallowing_all_pms,
        is_disallowing_pms_from_acting_user: false,
      )
    end

    # If any of the users has allowed_pm_users enabled check to see if the creator
    # is in their list.
    users_with_allowed_pms = user_communication_preferences.select(&:enable_allowed_pm_users)

    if users_with_allowed_pms.any?
      user_ids_with_allowed_pms = users_with_allowed_pms.map(&:id)
      user_ids_acting_can_pm =
        AllowedPmUser
          .where(allowed_pm_user_id: acting_user.id, user_id: user_ids_with_allowed_pms)
          .pluck(:user_id)
          .uniq

      # If not in the list mark them as not accepting communication.
      user_ids_acting_cannot_pm = user_ids_with_allowed_pms - user_ids_acting_can_pm
      user_ids_acting_cannot_pm.each do |user_id|
        if resolved_user_communication_preferences[user_id]
          resolved_user_communication_preferences[user_id].is_disallowing_pms_from_acting_user =
            true
        else
          resolved_user_communication_preferences[user_id] = UserCommPref.new(
            user_id: user_id,
            is_muting: false,
            is_ignoring: false,
            is_disallowing_all_pms: false,
            is_disallowing_pms_from_acting_user: true,
          )
        end
      end
    end

    UserCommPrefs.new(acting_user, resolved_user_communication_preferences)
  end

  def actor_preferences
    @actor_preferences ||=
      begin
        user_ids_by_preference_type =
          actor_communication_preferences.reduce({}) do |hash, pref|
            hash[pref.preference_type] ||= []
            hash[pref.preference_type] << pref.target_user_id
            hash
          end
        disallowed_pms_from =
          if acting_user.user_option.enable_allowed_pm_users
            (user_ids_by_preference_type["disallowed_pm"] || [])
          else
            []
          end
        {
          muting: user_ids_by_preference_type["muted"] || [],
          ignoring: user_ids_by_preference_type["ignored"] || [],
          disallowed_pms_from: disallowed_pms_from,
        }
      end
  end

  def user_communication_preferences
    @user_communication_preferences ||=
      DB.query(<<~SQL, acting_user_id: acting_user.id, target_user_ids: @target_users.keys)
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

  def actor_communication_preferences
    @actor_communication_preferences ||=
      DB.query(<<~SQL, acting_user_id: acting_user.id, target_user_ids: @target_users.keys)
      SELECT users.id AS target_user_id, 'disallowed_pm' AS preference_type FROM users
      LEFT JOIN allowed_pm_users ON allowed_pm_users.allowed_pm_user_id = users.id
      WHERE users.id IN (:target_user_ids)
      AND (allowed_pm_users.user_id = :acting_user_id OR allowed_pm_users.user_id IS NULL)
      AND allowed_pm_users.allowed_pm_user_id IS NULL
      UNION
      SELECT ignored_user_id AS target_user_id, 'ignored' AS preference_type
      FROM ignored_users
      WHERE user_id = :acting_user_id AND ignored_user_id IN (:target_user_ids)
      UNION
      SELECT muted_user_id AS target_user_id, 'muted' AS preference_type
      FROM muted_users
      WHERE user_id = :acting_user_id AND muted_user_id IN (:target_user_ids)
    SQL
  end

  def validate_user_id!(user_id)
    return if user_id == acting_user.id
    raise Discourse::NotFound if !@target_users.keys.include?(user_id)
  end
end
