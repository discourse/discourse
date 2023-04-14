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
             :post_edits_count,
             :flags_given_count,
             :flags_received_count,
             :private_topics_count,
             :can_delete_all_posts,
             :can_be_deleted,
             :can_be_anonymized,
             :can_be_merged,
             :full_suspend_reason,
             :suspended_till,
             :silence_reason,
             :penalty_counts,
             :next_penalty,
             :primary_group_id,
             :badge_count,
             :warnings_received_count,
             :user_fields,
             :bounce_score,
             :reset_bounce_score_after,
             :can_view_action_logs,
             :second_factor_enabled,
             :can_disable_second_factor,
             :can_delete_sso_record,
             :api_key_count,
             :external_ids,
             :similar_users,
             :similar_users_count

  has_one :approved_by, serializer: BasicUserSerializer, embed: :objects
  has_one :suspended_by, serializer: BasicUserSerializer, embed: :objects
  has_one :silenced_by, serializer: BasicUserSerializer, embed: :objects
  has_one :tl3_requirements, serializer: TrustLevel3RequirementsSerializer, embed: :objects
  has_many :groups, embed: :object, serializer: BasicGroupSerializer

  def second_factor_enabled
    object.totp_enabled? || object.security_keys_enabled?
  end

  def can_disable_second_factor
    scope.is_admin? && (object&.id != scope.user.id)
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

  def can_be_merged
    scope.can_merge_user?(object)
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

  def penalty_counts
    TrustLevel3Requirements.new(object).penalty_counts
  end

  def next_penalty
    step_number = penalty_counts.total
    steps = SiteSetting.penalty_step_hours.split("|")
    step_number = [step_number, steps.length].min
    penalty_hours = steps[step_number]
    Integer(penalty_hours, 10).hours.from_now
  rescue StandardError
    nil
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

  def external_ids
    external_ids = {}

    object.user_associated_accounts.map do |user_associated_account|
      external_ids[user_associated_account.provider_name] = user_associated_account.provider_uid
    end

    external_ids
  end

  def similar_users
    ActiveModel::ArraySerializer.new(
      @options[:similar_users],
      each_serializer: SimilarAdminUserSerializer,
      scope: scope,
      root: false,
    ).as_json
  end

  def include_similar_users?
    @options[:similar_users].present?
  end

  def similar_users_count
    @options[:similar_users_count]
  end

  def include_similar_users_count?
    @options[:similar_users].present?
  end

  def can_delete_sso_record
    scope.can_delete_sso_record?(object)
  end
end
