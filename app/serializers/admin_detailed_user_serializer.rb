class AdminDetailedUserSerializer < AdminUserSerializer

  attributes :moderator,
             :can_grant_admin, 
             :can_impersonate, 
             :can_revoke_admin,
             :like_count,
             :post_count,
             :flags_given_count,
             :flags_received_count,
             :private_topics_count

  has_one :approved_by, serializer: BasicUserSerializer, embed: :objects

  def can_revoke_admin
    scope.can_revoke_admin?(object)
  end

  def can_grant_admin
    scope.can_grant_admin?(object)
  end

  def moderator
    object.has_trust_level?(:moderator)
  end

end
