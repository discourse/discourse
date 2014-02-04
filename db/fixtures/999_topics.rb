User.reset_column_information
Topic.reset_column_information
Post.reset_column_information

if Topic.where('id NOT IN (SELECT topic_id from categories where topic_id is not null)').count == 0 && !Rails.env.test?
  puts "Seeding welcome topics"

  welcome = File.read(Rails.root + 'docs/ADMIN-QUICK-START-GUIDE.md')
  PostCreator.create(Discourse.system_user, raw: welcome, title: "Discourse Admin Quick Start Guide" ,skip_validations: true)

  welcome = File.read(Rails.root + 'docs/WELCOME-TO-DISCOURSE.md')
  post = PostCreator.create(Discourse.system_user, category: 'Meta', raw: welcome, title: "Welcome to Discourse", skip_validations: true)
  post.topic.update_pinned(true)
end
