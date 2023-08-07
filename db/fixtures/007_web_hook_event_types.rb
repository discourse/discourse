# frozen_string_literal: true

WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:topic][:created]
  b.name = "topic_created"
  b.group = "topic"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:topic][:revised]
  b.name = "topic_revised"
  b.group = "topic"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:topic][:changed]
  b.name = "topic_changed"
  b.group = "topic"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:topic][:deleted]
  b.name = "topic_deleted"
  b.group = "topic"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:post][:created]
  b.name = "post_created"
  b.group = "post"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:post][:updated]
  b.name = "post_updated"
  b.group = "post"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:post][:deleted]
  b.name = "post_deleted"
  b.group = "post"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:post][:recovered]
  b.name = "post_recovered"
  b.group = "post"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:user][:logged_in]
  b.name = "user_logged_in"
  b.group = "user"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:user][:logged_out]
  b.name = "user_logged_out"
  b.group = "user"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:user][:CONFIRMED_EMAIL]
  b.name = "user_confirmed_email"
  b.group = "user"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:user][:created]
  b.name = "user_created"
  b.group = "user"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:user][:approved]
  b.name = "user_approved"
  b.group = "user"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:user][:updated]
  b.name = "user_updated"
  b.group = "user"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:group][:created]
  b.name = "group_created"
  b.group = "group"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:group][:updated]
  b.name = "group_updated"
  b.group = "group"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:group][:deleted]
  b.name = "group_deleted"
  b.group = "group"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:category][:created]
  b.name = "category_created"
  b.group = "category"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:category][:updated]
  b.name = "category_updated"
  b.group = "category"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:category][:deleted]
  b.name = "category_deleted"
  b.group = "category"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:tag][:created]
  b.name = "tag_created"
  b.group = "tag"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:tag][:updated]
  b.name = "tag_updated"
  b.group = "tag"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:tag][:deleted]
  b.name = "tag_deleted"
  b.group = "tag"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:reviewable][:ready]
  b.name = "reviewable_ready"
  b.group = "reviewable"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:reviewable][:updated]
  b.name = "reviewable_updated"
  b.group = "reviewable"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:notification][:user_receives]
  b.name = "notification_user_receives"
  b.group = "notification"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:solved][:accept_unaccept]
  b.name = "solved_accept_unaccept"
  b.group = "solved"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:assign][:assign_unassign]
  b.name = "assign_assign_unassign"
  b.group = "assign"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:user_badge][:granted]
  b.name = "user_badge_granted"
  b.group = "user_badge"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:group_user][:added]
  b.name = "group_user_added"
  b.group = "group_user"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:group_user][:removed]
  b.name = "group_user_removed"
  b.group = "group_user"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:like][:created]
  b.name = "like_created"
  b.group = "like"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:user_promoted][:created]
  b.name = "user_promoted_created"
  b.group = "user_promoted"
end

WebHookEventType.seed do |b|
  b.id = WebHookEventType::TOPIC_VOTING
  b.name = "topic_voting"
end

WebHookEventType.seed do |b|
  b.id = WebHookEventType::CHAT_MESSAGE
  b.name = "chat_message"
end
