class FlaggedUserSerializer < BasicUserSerializer
  attributes :can_delete_all_posts,
             :can_be_deleted,
             :post_count,
             :topic_count,
             :ip_address,
             :custom_fields,
             :flags_agreed,
             :flags_disagreed,
             :flags_ignored

  def can_delete_all_posts
    scope.can_delete_all_posts?(object)
  end

  def can_be_deleted
    scope.can_delete_user?(object)
  end

  def ip_address
    object.ip_address.try(:to_s)
  end

  def flags_agreed
    object.user_stat.flags_agreed
  end

  def flags_disagreed
    object.user_stat.flags_disagreed
  end

  def flags_ignored
    object.user_stat.flags_ignored
  end

  def custom_fields
    fields = User.whitelisted_user_custom_fields(scope)

    result = {}
    fields.each do |k|
      result[k] = object.custom_fields[k] if object.custom_fields[k].present?
    end

    result
  end

end
