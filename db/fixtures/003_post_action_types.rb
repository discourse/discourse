# frozen_string_literal: true
post_action_type_view = PostActionTypeView.new

PostActionType.seed do |s|
  s.id = post_action_type_view.types[:like]
  s.name_key = "like"
  s.is_flag = false
  s.icon = "heart"
  s.position = 2
end

if post_action_type_view.types[:off_topic]
  PostActionType.seed do |s|
    s.id = post_action_type_view.types[:off_topic]
    s.name_key = "off_topic"
    s.is_flag = true
    s.position = 3
  end
end

if post_action_type_view.types[:inappropriate]
  PostActionType.seed do |s|
    s.id = post_action_type_view.types[:inappropriate]
    s.name_key = "inappropriate"
    s.is_flag = true
    s.position = 4
  end
end

if post_action_type_view.types[:spam]
  PostActionType.seed do |s|
    s.id = post_action_type_view.types[:spam]
    s.name_key = "spam"
    s.is_flag = true
    s.position = 6
  end
end

if post_action_type_view.types[:notify_user]
  PostActionType.seed do |s|
    s.id = post_action_type_view.types[:notify_user]
    s.name_key = "notify_user"
    s.is_flag = true
    s.position = 7
  end
end

if post_action_type_view.types[:notify_moderators]
  PostActionType.seed do |s|
    s.id = post_action_type_view.types[:notify_moderators]
    s.name_key = "notify_moderators"
    s.is_flag = true
    s.position = 8
  end
end
