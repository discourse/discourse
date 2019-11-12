# frozen_string_literal: true

class AdminDetailedUserSerializer < AdminUserSerializer

  attributes :moderator,
             :can_grant_admin,
             :can_revoke_admin,
             :can_grant_moderation,
             :can_revoke_moderation,
             :can_impersonate,
             :like_count,
             :like_given_count,
             :post_count,
             :topic_count,
             :flags_given_count,
             :flags_received_count,
             :private_topics_count,
             :can_delete_all_posts,
             :can_be_deleted,
             :can_be_anonymized,
             :full_suspend_reason,
             :suspended_till,
             :silence_reason,
             :primary_group_id,
             :badge_count,
             :warnings_received_count,
             :user_fields,
             :bounce_score,
             :reset_bounce_score_after,
             :can_view_action_logs,
             :second_factor_enabled,
             :can_disable_second_factor,
             :api_key_count

  has_one :approved_by, serializer: BasicUserSerializer, embed: :objects
  has_one :suspended_by, serializer: BasicUserSerializer, embed: :objects
  has_one :silenced_by, serializer: BasicUserSerializer, embed: :objects
  has_one :tl3_requirements, serializer: TrustLevel3RequirementsSerializer, embed: :objects
  has_many :groups, embed: :object, serializer: BasicGroupSerializer

  def second_factor_enabled
    object.totp_enabled? || object.security_keys_enabled?
  end

  def can_disable_second_factor
    object&.id != scope.user.id
  end

  def can_revoke_admin
    scope.can_revoke_admin?(object)
  end

  def can_grant_admin
    scope.can_grant_admin?(object)
  end

  def can_revoke_moderation
    scope.can_revoke_moderation?(object)
  end

  def can_grant_moderation
    scope.can_grant_moderation?(object)
  end

  def can_delete_all_posts
    scope.can_delete_all_posts?(object)
  end

  def can_be_deleted
    scope.can_delete_user?(object)
  end

  def can_be_anonymized
    scope.can_anonymize_user?(object)
  end

  def topic_count
    object.topics.count
  end

  def include_api_key?
    scope.is_admin? && api_key.present?
  end

  def suspended_by
    object.suspend_record.try(:acting_user)
  end

  def silence_reason
    object.silence_reason
  end

  def silenced_by
    object.silenced_record.try(:acting_user)
  end

  def include_tl3_requirements?
    object.has_trust_level?(TrustLevel[2])
  end

  def include_user_fields?
    object.user_fields.present?
  end

  def bounce_score
    object.user_stat.bounce_score
  end

  def reset_bounce_score_after
    object.user_stat.reset_bounce_score_after
  end

  def can_view_action_logs
    scope.can_view_action_logs?(object)
  end

  def post_count
    object.posts.count
  end

  def api_key_count
    object.api_keys.active.count
  end
end
