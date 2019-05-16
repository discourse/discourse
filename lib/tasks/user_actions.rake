# frozen_string_literal: true

desc "rebuild the user_actions table"
task "user_actions:rebuild" => :environment do
  MessageBus.off
  UserAction.delete_all
  PostAction.all.each do |i|
    if i.deleted_at.nil?
      UserActionManager.post_action_created(i)
    else
      UserActionManager.post_action_destroyed(i)
    end
  end
  Topic.all.each { |i| UserActionManager.log_topic(i) }
  Post.all.each do |i|
    if i.deleted_at.nil?
      UserActionManager.post_created(i)
    else
      UserActionManager.post_destroyed(i)
    end
  end
  Notification.all.each do |notification|

    if notification.post.deleted_at.nil?
      UserActionManager.notification_created(
        notification.post,
        notification.user,
        notification.notification_type,
        notification.user
      )
    else
      UserActionManager.notification_destroyed(
        notification.post,
        notification.user,
        notification.notification_type,
        notification.user
      )
    end

  end
end
