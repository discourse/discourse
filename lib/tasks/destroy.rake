## These tasks are destructive and are for clearing out all the
#   content and users from your site, but keeping your site settings,
#   theme, and category structure.
desc "Remove all topics in a category"
task "destroy:topics", [:category] => :environment do |t, args|
  category = args[:category]
  puts "Going to delete all topics in the #{category} category"
  puts log = DestroyTask.destroy_topics(category)
end

desc "Remove all topics in all categories"
task "destroy:topics_all_categories" => :environment do
  puts "Going to delete all topics in all categories..."
  puts log = DestroyTask.destroy_topics_all_categories
end

desc "Remove all private messages"
task "destroy:private_messages" => :environment do
  puts "Going to delete all private messages..."
  puts log = DestroyTask.destroy_private_messages
end

desc "Destroy all groups"
task "destroy:groups" => :environment do
  puts "Going to delete all non-default groups..."
  puts log = DestroyTask.destroy_groups
end

desc "Destroy all non-admin users"
task "destroy:users" => :environment do
  puts "Going to delete all non-admin users..."
  puts log = DestroyTask.destroy_users
end

desc "Destroy site stats"
task "destroy:stats" => :environment do
  puts "Going to delete all site stats..."
  DestroyTask.destroy_stats
end
