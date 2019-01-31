User.reset_column_information
Topic.reset_column_information
Post.reset_column_information

staff = Category.find_by(id: SiteSetting.staff_category_id)
seed_welcome_topics = (Topic.where('id NOT IN (SELECT topic_id from categories where topic_id is not null)').count == 0 && !Rails.env.test?)

unless Rails.env.test?
  def create_static_page_topic(site_setting_key, title_key, body_key, body_override, category, description, params = {})
    unless SiteSetting.send(site_setting_key) > 0
      creator = PostCreator.new(Discourse.system_user,
                                 title: I18n.t(title_key, default: I18n.t(title_key, locale: :en)),
                                 raw: body_override.present? ? body_override : I18n.t(body_key, params.merge(default: I18n.t(body_key, params.merge(locale: :en)))),
                                 skip_validations: true,
                                 category: category ? category.name : nil)
      post = creator.create

      raise "Failed to create the #{description} topic! #{creator.errors.full_messages.join('. ')}" if creator.errors.present?

      SiteSetting.send("#{site_setting_key}=", post.topic_id)

      _reply = PostCreator.create(Discourse.system_user,
                                  raw: I18n.t('static_topic_first_reply', page_name: I18n.t(title_key, default: I18n.t(title_key, locale: :en))),
                                  skip_validations: true,
                                  topic_id: post.topic_id)
    end
  end

  create_static_page_topic('tos_topic_id', 'tos_topic.title', "tos_topic.body", nil, staff, "terms of service",
                           company_name: SiteSetting.company_name.presence || "company_name",
                           base_url: Discourse.base_url,
                           contact_email: SiteSetting.contact_email.presence || "contact_email",
                           governing_law: SiteSetting.governing_law.presence || "governing_law",
                           city_for_disputes: SiteSetting.city_for_disputes.presence || "city_for_disputes")

  create_static_page_topic('guidelines_topic_id', 'guidelines_topic.title', "guidelines_topic.body", nil, staff, "guidelines", base_path: Discourse.base_path)

  create_static_page_topic('privacy_topic_id', 'privacy_topic.title', "privacy_topic.body", nil, staff, "privacy policy")
end

if seed_welcome_topics
  puts "Seeding welcome topics"

  post = PostCreator.create(Discourse.system_user, raw: I18n.t('discourse_welcome_topic.body', base_path: Discourse.base_path), title: I18n.t('discourse_welcome_topic.title'), skip_validations: true)
  post.topic.update_pinned(true, true)
  TopicCustomField.create(topic_id: post.topic.id, name: "is_welcome_topic", value: "true")

  lounge = Category.find_by(id: SiteSetting.lounge_category_id)
  if lounge
    post = PostCreator.create(Discourse.system_user, raw: I18n.t('lounge_welcome.body', base_path: Discourse.base_path), title: I18n.t('lounge_welcome.title'), skip_validations: true, category: lounge.name)
    post.topic.update_pinned(true)
  end

  filename = DiscoursePluginRegistry.seed_data["admin_quick_start_filename"]
  if filename.nil? || !File.exists?(filename)
    filename = Rails.root + 'docs/ADMIN-QUICK-START-GUIDE.md'
  end

  welcome = File.read(filename)
  PostCreator.create(Discourse.system_user,
                      raw: welcome,
                      title: DiscoursePluginRegistry.seed_data["admin_quick_start_title"] || "READ ME FIRST: Admin Quick Start Guide",
                      skip_validations: true,
                      category: staff ? staff.name : nil)
end
