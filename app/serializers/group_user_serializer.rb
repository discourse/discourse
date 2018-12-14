class GroupUserSerializer < BasicUserSerializer
  include UserPrimaryGroupMixin

  attributes :name,
             :title,
             :last_posted_at,
             :last_seen_at,
             :added_at

  def include_added_at
    object.respond_to? :added_at
  end

end
