PostActionType.seed do |s|
  s.id = PostActionType.types[:bookmark]
  s.name_key = 'bookmark'
  s.is_flag = false
  s.position = 1
end

PostActionType.seed do |s|
  s.id = PostActionType.types[:like]
  s.name_key = 'like'
  s.is_flag = false
  s.icon = 'heart'
  s.position = 2
end

PostActionType.seed do |s|
  s.id = PostActionType.types[:off_topic]
  s.name_key = 'off_topic'
  s.is_flag = true
  s.position = 3
end

PostActionType.seed do |s|
  s.id = PostActionType.types[:inappropriate]
  s.name_key = 'inappropriate'
  s.is_flag = true
  s.position = 4
end

PostActionType.seed do |s|
  s.id = PostActionType.types[:spam]
  s.name_key = 'spam'
  s.is_flag = true
  s.position = 6
end

PostActionType.seed do |s|
  s.id = PostActionType.types[:notify_user]
  s.name_key = 'notify_user'
  s.is_flag = true
  s.position = 7
end

PostActionType.seed do |s|
  s.id = PostActionType.types[:notify_moderators]
  s.name_key = 'notify_moderators'
  s.is_flag = true
  s.position = 8
end
