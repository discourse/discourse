User.reset_column_information
Topic.reset_column_information
Post.reset_column_information

if Topic.where('id NOT IN (SELECT topic_id from categories where topic_id is not null)').count == 0 && !Rails.env.test?
  puts "Seeding welcome topics"

  staff = Category.find_by(id: SiteSetting.staff_category_id)
  welcome = File.read(Rails.root + 'docs/ADMIN-QUICK-START-GUIDE.md')
  PostCreator.create(Discourse.system_user, raw: welcome, title: "READ ME FIRST: Admin Quick Start Guide", skip_validations: true, category: staff ? staff.name : nil)
  PostCreator.create(Discourse.system_user, raw: I18n.t('assets_topic_body'), title: "Assets for the forum design", skip_validations: true, category: staff ? staff.name : nil)

  welcome = File.read(Rails.root + 'docs/WELCOME-TO-DISCOURSE.md')
  post = PostCreator.create(Discourse.system_user, raw: welcome, title: "Welcome to Discourse", skip_validations: true)
  post.topic.update_pinned(true, true)
end
