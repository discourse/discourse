# frozen_string_literal: true

desc "Creates sample categories"
task "groups:populate" => ["db:load_config"] do |_, args|
  DiscourseDev::Group.populate!
end

desc "Creates sample user accounts"
task "users:populate" => ["db:load_config"] do |_, args|
  DiscourseDev::User.populate!
end

desc "Creates sample categories"
task "categories:populate" => ["db:load_config"] do |_, args|
  DiscourseDev::Category.populate!
end

desc "Creates sample tags"
task "tags:populate" => ["db:load_config"] do |_, args|
  DiscourseDev::Tag.populate!
end

desc "Creates sample topics"
task "topics:populate" => ["db:load_config"] do |_, args|
  if ENV["IGNORE_CURRENT_COUNT"] == "true"
    DiscourseDev::Topic.populate!(ignore_current_count: true)
  else
    DiscourseDev::Topic.populate!
  end
end

desc "Creates sample reviewables"
task "reviewables:populate" => ["db:load_config"] do |_, args|
  DiscourseDev::Reviewable.populate!
end

desc "Creates sample private messages"
task "private_messages:populate", [:recipient] => ["db:load_config"] do |_, args|
  args.with_defaults(type: "string")

  if !args[:recipient]
    puts "ERROR: Expecting rake private_messages:populate[recipient]"
    exit 1
  end

  DiscourseDev::Topic.populate!(
    private_messages: true,
    recipient: args[:recipient],
    ignore_current_count: true,
  )
end

desc "Create post revisions"
task "post_revisions:populate" => ["db:load_config"] do |_, args|
  DiscourseDev::PostRevision.populate!
end

desc "Add replies to a topic"
task "replies:populate", %i[topic_id count] => ["db:load_config"] do |_, args|
  DiscourseDev::Post.add_replies!(args)
end

desc "Creates sample email logs"
task "email_logs:populate" => ["db:load_config"] do |_, args|
  DiscourseDev::EmailLog.populate!
end
