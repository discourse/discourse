# frozen_string_literal: true

PostActionType.seed do |s|
  s.id = 2
  s.name_key = "like"
  s.is_flag = false
  s.icon = "heart"
  s.position = 2
  s.skip_expire_cache_callback = true
end

PostActionType.seed do |s|
  s.id = 3
  s.name_key = "off_topic"
  s.is_flag = true
  s.position = 3
  s.skip_expire_cache_callback = true
end

PostActionType.seed do |s|
  s.id = 4
  s.name_key = "inappropriate"
  s.is_flag = true
  s.position = 4
  s.skip_expire_cache_callback = true
end

PostActionType.seed do |s|
  s.id = 8
  s.name_key = "spam"
  s.is_flag = true
  s.position = 6
  s.skip_expire_cache_callback = true
end

PostActionType.seed do |s|
  s.id = 6
  s.name_key = "notify_user"
  s.is_flag = true
  s.position = 7
  s.skip_expire_cache_callback = true
end

PostActionType.seed do |s|
  s.id = 7
  s.name_key = "notify_moderators"
  s.is_flag = true
  s.position = 8
  s.skip_expire_cache_callback = true
end
