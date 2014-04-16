class AdminDetailedUserSerializer < AdminUserSerializer

  attributes :moderator,
             :can_grant_admin,
             :can_revoke_admin,
             :can_grant_moderation,
             :can_revoke_moderation,
             :can_impersonate,
             :like_count,
             :post_count,
             :topic_count,
             :flags_given_count,
             :flags_received_count,
             :private_topics_count,
             :can_delete_all_posts,
             :can_be_deleted,
             :suspend_reason,
             :primary_group_id,
             :badge_count

  has_one :approved_by, serializer: BasicUserSerializer, embed: :objects
  has_one :api_key, serializer: ApiKeySerializer, embed: :objects
  has_one :suspended_by, serializer: BasicUserSerializer, embed: :objects
  has_one :leader_requirements, serializer: LeaderRequirementsSerializer, embed: :objects
  has_many :custom_groups, embed: :object, serializer: BasicGroupSerializer

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

  def moderator
    object.moderator
  end

  def topic_count
    object.topics.count
  end

  def include_api_key?
    api_key.present?
  end

  def suspended_by
    object.suspend_record.try(:acting_user)
  end

  def leader_requirements
    object.leader_requirements
  end

  def include_leader_requirements?
    object.has_trust_level?(:regular)
  end

end
