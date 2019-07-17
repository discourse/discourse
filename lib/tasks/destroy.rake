# frozen_string_literal: true

## These tasks are destructive and are for clearing out all the
#   content and users from your site.
desc "Remove all topics in a category"
task "destroy:topics", [:category, :parent_category] => :environment do |t, args|
  destroy_task = DestroyTask.new
  category = args[:category]
  parent_category = args[:parent_category]
  descriptive_slug = parent_category ? "#{parent_category}/#{category}" : category
  puts "Going to delete all topics in the #{descriptive_slug} category"
  destroy_task.destroy_topics(category, parent_category)
end

desc "Remove all topics in all categories"
task "destroy:topics_all_categories" => :environment do
  destroy_task = DestroyTask.new
  puts "Going to delete all topics in all categories..."
  puts log = destroy_task.destroy_topics_all_categories
end

desc "Remove all private messages"
task "destroy:private_messages" => :environment do
  destroy_task = DestroyTask.new
  puts "Going to delete all private messages..."
  puts log = destroy_task.destroy_private_messages
end

desc "Destroy all groups"
task "destroy:groups" => :environment do
  destroy_task = DestroyTask.new
  puts "Going to delete all non-default groups..."
  puts log = destroy_task.destroy_groups
end

desc "Destroy all non-admin users"
task "destroy:users" => :environment do
  destroy_task = DestroyTask.new
  puts "Going to delete all non-admin users..."
  puts log = destroy_task.destroy_users
end

desc "Destroy site stats"
task "destroy:stats" => :environment do
  destroy_task = DestroyTask.new
  puts "Going to delete all site stats..."
  destroy_task.destroy_stats
end

# Example: rake destroy:categories[28,29,44,85]
# Run rake categories:list for a list of category ids
desc "Destroy a comma separated list of category ids."
task "destroy:categories" => :environment do |t, args|
  destroy_task = DestroyTask.new
  categories = args.extras
  puts "Going to delete these categories: #{categories}"
  categories.each do |id|
    destroy_task.destroy_category(id, true)
  end
end
