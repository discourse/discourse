class GroupUserSerializer < BasicUserSerializer
  attributes :name, :last_posted_at, :last_seen_at
end
