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
  s.id = PostActionType.types[:vote]
  s.name_key = 'vote'
  s.is_flag = false
  s.position = 5
end

PostActionType.seed do |s|
  s.id = PostActionType.types[:spam]
  s.name_key = 'spam'
  s.is_flag = true
  s.position = 6
end

PostActionType.seed do |s|
  s.id = PostActionType.types[:custom_flag]
  s.name_key = 'custom_flag'
  s.is_flag = true
  s.position = 7
end

