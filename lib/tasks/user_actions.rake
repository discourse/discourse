desc "rebuild the user_actions table"
task "user_actions:rebuild" => :environment do
  MessageBus.off
  UserAction.delete_all
  PostAction.all.each { |i| UserActionCreator.log_post_action(i) }
  Topic.all.each { |i| UserActionCreator.log_topic(i) }
  Post.all.each { |i| UserActionCreator.log_post(i) }
  Notification.all.each do |notification|
    UserActionCreator.log_notification(notification.post,
                                       notification.user,
                                       notification.notification_type,
                                       notification.user)
  end
end
