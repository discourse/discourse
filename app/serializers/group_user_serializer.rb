class GroupUserSerializer < BasicUserSerializer
  attributes :name, :title, :last_posted_at, :last_seen_at
end
