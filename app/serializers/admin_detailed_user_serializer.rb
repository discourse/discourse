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
             :can_be_deleted

  has_one :approved_by, serializer: BasicUserSerializer, embed: :objects
  has_one :api_key, serializer: ApiKeySerializer, embed: :objects

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

end
