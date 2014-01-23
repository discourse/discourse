User.reset_column_information
Topic.reset_column_information
Post.reset_column_information

if Topic.where('id NOT IN (SELECT topic_id from categories where topic_id is not null)').count == 0 && !Rails.env.test?
  # seed welcome topic
  puts "Seeding welcome topic"
  welcome = File.read(Rails.root + 'docs/ADMIN-QUICK-START-GUIDE.md')
  PostCreator.create(Discourse.system_user, raw: welcome, title: "Discourse Admin Quick Start Guide" ,skip_validations: true)
end
