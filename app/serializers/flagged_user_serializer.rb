class FlaggedUserSerializer < BasicUserSerializer
  attributes :can_delete_all_posts,
             :can_be_deleted,
             :post_count,
             :topic_count,
             :email,
             :ip_address

  def can_delete_all_posts
    scope.can_delete_all_posts?(object)
  end

  def can_be_deleted
    scope.can_delete_user?(object)
  end

  def ip_address
    object.ip_address.try(:to_s)
  end

end
