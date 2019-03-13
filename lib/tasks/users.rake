desc "Change topic/post ownership of all the topics/posts by a specific user (without creating new revision)"
task "users:change_post_ownership", [:old_username, :new_username, :archetype] => [:environment] do |_, args|
  old_username = args[:old_username]
  new_username = args[:new_username]
  archetype = args[:archetype]
  archetype = archetype.downcase if archetype

  if !old_username || !new_username
    puts "ERROR: Expecting rake users:change_post_ownership[old_username,new_username,archetype]"
    exit 1
  end

  old_user = find_user(old_username)
  new_user = find_user(new_username)

  if archetype == "private"
    posts = Post.private_posts.where(user_id: old_user.id)
  elsif archetype == "public" || !archetype
    posts = Post.public_posts.where(user_id: old_user.id)
  else
    puts "ERROR: Expecting rake users:change_post_ownership[old_username,new_username,archetype] where archetype is public or private"
    exit 1
  end

  puts "Changing post ownership"
  i = 0
  posts.each do |p|
    PostOwnerChanger.new(post_ids: [p.id], topic_id: p.topic.id, new_owner: User.find_by(username_lower: new_user.username_lower), acting_user: User.find_by(username_lower: "system"), skip_revision: true).change_owner!
    putc "."
    i += 1
  end
  puts "", "#{i} posts ownership changed!", ""
end

desc "Merge the source user into the target user"
task "users:merge", [:source_username, :target_username] => [:environment] do |_, args|
  source_username = args[:source_username]
  target_username = args[:target_username]

  if !source_username || !target_username
    puts "ERROR: Expecting rake users:merge[source_username,target_username]"
    exit 1
  end

  source_user = find_user(source_username)
  target_user = find_user(target_username)

  UserMerger.new(source_user, target_user).merge!
  puts "", "Users merged!", ""
end

desc "Rename a user"
task "users:rename", [:old_username, :new_username] => [:environment] do |_, args|
  old_username = args[:old_username]
  new_username = args[:new_username]

  if !old_username || !new_username
    puts "ERROR: Expecting rake users:rename[old_username,new_username]"
    exit 1
  end

  changer = UsernameChanger.new(find_user(old_username), new_username)
  changer.change(asynchronous: false)
  puts "", "User renamed!", ""
end

desc "Update username in quotes and mentions. Use this if the user was renamed before proper renaming existed."
task "users:update_posts", [:old_username, :current_username] => [:environment] do |_, args|
  old_username = args[:old_username]
  current_username = args[:current_username]

  if !old_username || !current_username
    puts "ERROR: Expecting rake users:update_posts[old_username,current_username]"
    exit 1
  end

  user = find_user(current_username)
  UsernameChanger.update_username(user_id: user.id,
                                  old_username: old_username,
                                  new_username: user.username,
                                  avatar_template: user.avatar_template,
                                  asynchronous: false)

  puts "", "Username updated!", ""
end

desc 'Recalculate post and topic counts in user stats'
task 'users:recalculate_post_counts' => :environment do
  puts '', 'Updating user stats...'

  filter_public_posts_and_topics = <<~SQL
    p.deleted_at IS NULL
     AND NOT COALESCE(p.hidden, 't')
     AND p.post_type = 1
     AND t.deleted_at IS NULL
     AND COALESCE(t.visible, 't')
     AND t.archetype <> 'private_message'
     AND p.user_id > 0
  SQL

  puts 'post counts...'

  # all public replies
  DB.exec <<~SQL
    WITH X AS (
      SELECT p.user_id, COUNT(p.id) post_count
    FROM posts p
    JOIN topics t ON t.id = p.topic_id
   WHERE #{filter_public_posts_and_topics}
     AND p.post_number > 1
GROUP BY p.user_id
    )
    UPDATE user_stats
       SET post_count = X.post_count
      FROM X
     WHERE user_stats.user_id = X.user_id
       AND user_stats.post_count <> X.post_count
  SQL

  puts 'topic counts...'

  # public topics
  DB.exec <<~SQL
    WITH X AS (
      SELECT p.user_id, COUNT(p.id) topic_count
    FROM posts p
    JOIN topics t ON t.id = p.topic_id
   WHERE #{filter_public_posts_and_topics}
     AND p.post_number = 1
GROUP BY p.user_id
    )
    UPDATE user_stats
       SET topic_count = X.topic_count
      FROM X
     WHERE user_stats.user_id = X.user_id
       AND user_stats.topic_count <> X.topic_count
  SQL

  puts 'Done!', ''
end

desc "Disable 2FA for user with the given username"
task "users:disable_2fa", [:username] => [:environment] do |_, args|
  username = args[:username]
  user = find_user(username)
  UserSecondFactor.where(user_id: user.id, method: UserSecondFactor.methods[:totp]).each(&:destroy!)
  puts "2FA disabled for #{username}"
end

desc "Anonymize all users except staff"
task "users:anonymize_all" => :environment do
  require 'highline/import'

  non_staff_users = User.where('NOT admin AND NOT moderator')
  total = non_staff_users.count
  anonymized = 0

  confirm_anonymize = ask("Are you sure you want to anonymize #{total} users? (Y/n)")
  exit 1 unless (confirm_anonymize == "" || confirm_anonymize.downcase == 'y')

  system_user = Discourse.system_user
  non_staff_users.each do |user|
    begin
      UserAnonymizer.new(user, system_user).make_anonymous
      print_status(anonymized += 1, total)
    rescue
      # skip
    end
  end

  puts "", "#{total} users anonymized.", ""
end

desc "List all users which have been staff in the last month"
task "users:list_recent_staff" => :environment do
  current_staff_ids = User.human_users.where("admin OR moderator").pluck(:id)
  recent_actions = UserHistory.where("created_at > ?", 1.month.ago)
  recent_admin_ids = recent_actions.where(action: UserHistory.actions[:revoke_admin]).pluck(:target_user_id)
  recent_moderator_ids = recent_actions.where(action: UserHistory.actions[:revoke_moderation]).pluck(:target_user_id)

  all_ids = current_staff_ids + recent_admin_ids + recent_moderator_ids
  users = User.where(id: all_ids.uniq)

  puts "Users which have had staff privileges in the last month:"
  users.each do |user|
    puts "#{user.id}: #{user.username} (#{user.email})"
  end
  puts "----"
  puts "user_ids = [#{all_ids.uniq.join(',')}]"
end

def find_user(username)
  user = User.find_by_username(username)

  if !user
    puts "ERROR: User with username #{username} does not exist"
    exit 1
  end

  user
end
