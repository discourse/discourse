# frozen_string_literal: true

WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:topic][:created]
  b.name = "topic_created"
  b.group = WebHookEventType.groups[:topic]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:topic][:revised]
  b.name = "topic_revised"
  b.group = WebHookEventType.groups[:topic]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:topic][:edited]
  b.name = "topic_edited"
  b.group = WebHookEventType.groups[:topic]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:topic][:destroyed]
  b.name = "topic_destroyed"
  b.group = WebHookEventType.groups[:topic]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:topic][:recovered]
  b.name = "topic_recovered"
  b.group = WebHookEventType.groups[:topic]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:post][:created]
  b.name = "post_created"
  b.group = WebHookEventType.groups[:post]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:post][:edited]
  b.name = "post_edited"
  b.group = WebHookEventType.groups[:post]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:post][:destroyed]
  b.name = "post_destroyed"
  b.group = WebHookEventType.groups[:post]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:post][:recovered]
  b.name = "post_recovered"
  b.group = WebHookEventType.groups[:post]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:user][:logged_in]
  b.name = "user_logged_in"
  b.group = WebHookEventType.groups[:user]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:user][:logged_out]
  b.name = "user_logged_out"
  b.group = WebHookEventType.groups[:user]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:user][:confirmed_email]
  b.name = "user_confirmed_email"
  b.group = WebHookEventType.groups[:user]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:user][:created]
  b.name = "user_created"
  b.group = WebHookEventType.groups[:user]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:user][:approved]
  b.name = "user_approved"
  b.group = WebHookEventType.groups[:user]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:user][:updated]
  b.name = "user_updated"
  b.group = WebHookEventType.groups[:user]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:user][:destroyed]
  b.name = "user_destroyed"
  b.group = WebHookEventType.groups[:user]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:user][:suspended]
  b.name = "user_suspended"
  b.group = WebHookEventType.groups[:user]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:user][:unsuspended]
  b.name = "user_unsuspended"
  b.group = WebHookEventType.groups[:user]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:group][:created]
  b.name = "group_created"
  b.group = WebHookEventType.groups[:group]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:group][:updated]
  b.name = "group_updated"
  b.group = WebHookEventType.groups[:group]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:group][:destroyed]
  b.name = "group_destroyed"
  b.group = WebHookEventType.groups[:group]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:category][:created]
  b.name = "category_created"
  b.group = WebHookEventType.groups[:category]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:category][:updated]
  b.name = "category_updated"
  b.group = WebHookEventType.groups[:category]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:category][:destroyed]
  b.name = "category_destroyed"
  b.group = WebHookEventType.groups[:category]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:tag][:created]
  b.name = "tag_created"
  b.group = WebHookEventType.groups[:tag]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:tag][:updated]
  b.name = "tag_updated"
  b.group = WebHookEventType.groups[:tag]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:tag][:destroyed]
  b.name = "tag_destroyed"
  b.group = WebHookEventType.groups[:tag]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:reviewable][:created]
  b.name = "reviewable_created"
  b.group = WebHookEventType.groups[:reviewable]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:reviewable][:updated]
  b.name = "reviewable_updated"
  b.group = WebHookEventType.groups[:reviewable]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:notification][:created]
  b.name = "notification_created"
  b.group = WebHookEventType.groups[:notification]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:solved][:accepted_solution]
  b.name = "accepted_solution"
  b.group = WebHookEventType.groups[:solved]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:solved][:unaccepted_solution]
  b.name = "unaccepted_solution"
  b.group = WebHookEventType.groups[:solved]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:assign][:assigned]
  b.name = "assigned"
  b.group = WebHookEventType.groups[:assign]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:assign][:unassigned]
  b.name = "unassigned"
  b.group = WebHookEventType.groups[:assign]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:user_badge][:granted]
  b.name = "user_badge_granted"
  b.group = WebHookEventType.groups[:user_badge]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:user_badge][:revoked]
  b.name = "user_badge_revoked"
  b.group = WebHookEventType.groups[:user_badge]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:group_user][:added]
  b.name = "user_added_to_group"
  b.group = WebHookEventType.groups[:group_user]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:group_user][:removed]
  b.name = "user_removed_from_group"
  b.group = WebHookEventType.groups[:group_user]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:like][:created]
  b.name = "post_liked"
  b.group = WebHookEventType.groups[:like]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:user_promoted][:created]
  b.name = "user_promoted"
  b.group = WebHookEventType.groups[:user_promoted]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:voting][:topic_upvote]
  b.name = "topic_upvote"
  b.group = WebHookEventType.groups[:voting]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:voting][:topic_unvote]
  b.name = "topic_unvote"
  b.group = WebHookEventType.groups[:voting]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:chat][:message_created]
  b.name = "chat_message_created"
  b.group = WebHookEventType.groups[:chat]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:chat][:message_edited]
  b.name = "chat_message_edited"
  b.group = WebHookEventType.groups[:chat]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:chat][:message_trashed]
  b.name = "chat_message_trashed"
  b.group = WebHookEventType.groups[:chat]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::TYPES[:chat][:message_restored]
  b.name = "chat_message_restored"
  b.group = WebHookEventType.groups[:chat]
end
