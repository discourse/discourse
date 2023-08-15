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
  b.id = WebHookEventType::TYPES[:topic][:edited]
  b.name = "topic_edited"
  b.group = "topic"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:topic][:destroyed]
  b.name = "topic_destroyed"
  b.group = "topic"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:topic][:recovered]
  b.name = "topic_recovered"
  b.group = "topic"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:post][:created]
  b.name = "post_created"
  b.group = "post"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:post][:edited]
  b.name = "post_edited"
  b.group = "post"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:post][:destroyed]
  b.name = "post_destroyed"
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
  b.id = WebHookEventType::TYPES[:user][:confirmed_email]
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
  b.id = WebHookEventType::TYPES[:user][:destroyed]
  b.name = "user_destroyed"
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
  b.id = WebHookEventType::TYPES[:group][:destroyed]
  b.name = "group_destroyed"
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
  b.id = WebHookEventType::TYPES[:category][:destroyed]
  b.name = "category_destroyed"
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
  b.id = WebHookEventType::TYPES[:tag][:destroyed]
  b.name = "tag_destroyed"
  b.group = "tag"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:reviewable][:created]
  b.name = "reviewable_created"
  b.group = "reviewable"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:reviewable][:updated]
  b.name = "reviewable_updated"
  b.group = "reviewable"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:notification][:created]
  b.name = "notification_created"
  b.group = "notification"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:solved][:accept_unaccept]
  b.name = "solved_accept_unaccept"
  b.group = "solved"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:assign][:assign]
  b.name = "assign"
  b.group = "assign"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:user_badge][:granted]
  b.name = "user_badge_granted"
  b.group = "user_badge"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:user_badge][:revoked]
  b.name = "user_badge_revoked"
  b.group = "user_badge"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:group_user][:added]
  b.name = "user_added_to_group"
  b.group = "group_user"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:group_user][:removed]
  b.name = "user_removed_from_group"
  b.group = "group_user"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:like][:created]
  b.name = "post_liked"
  b.group = "like"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:user_promoted][:created]
  b.name = "user_promoted"
  b.group = "user_promoted"
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:voting][:voted_unvoted]
  b.name = "voted_unvoted"
  b.group = "voting"
end

WebHookEventType.seed do |b|
  b.id = WebHookEventType::CHAT_MESSAGE
  b.name = "chat_message"
end
