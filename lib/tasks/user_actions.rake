desc "rebuild the user_actions table"
task "user_actions:rebuild" => :environment do
  o = UserActionObserver.send :new
  MessageBus.off
  UserAction.delete_all
  PostAction.all.each{|i| o.after_save(i)}
  Topic.all.each {|i| o.after_save(i)}
  Post.all.each {|i| o.after_save(i)}
  Notification.all.each {|i| o.after_save(i)}
  # not really needed but who knows
  MessageBus.on
end

