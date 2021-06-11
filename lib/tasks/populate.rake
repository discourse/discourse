# frozen_string_literal: true

desc 'Creates sample categories'
task 'groups:populate' => ['db:load_config'] do |_, args|
  DiscourseDev::Group.populate!
end

desc 'Creates sample user accounts'
task 'users:populate' => ['db:load_config'] do |_, args|
  DiscourseDev::User.populate!
end

desc 'Creates sample categories'
task 'categories:populate' => ['db:load_config'] do |_, args|
  DiscourseDev::Category.populate!
end

desc 'Creates sample tags'
task 'tags:populate' => ['db:load_config'] do |_, args|
  DiscourseDev::Tag.populate!
end

desc 'Creates sample topics'
task 'topics:populate' => ['db:load_config'] do |_, args|
  DiscourseDev::Topic.populate!
end

desc 'Add replies to a topic'
task 'replies:populate', [:topic_id, :count] => ['db:load_config'] do |_, args|
  DiscourseDev::Post.add_replies!(args)
end
