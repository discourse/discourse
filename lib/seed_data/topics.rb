module SeedData
  class Topics
    def self.with_default_locale
      SeedData::Topics.new(SiteSetting.default_locale)
    end

    def initialize(locale)
      @locale = locale
    end

    def create(include_welcome_topics)
      I18n.with_locale(@locale) do
        topics(include_welcome_topics).each { |topic| create_topic(topic) }
      end
    end

    def update
      I18n.with_locale(@locale) do
        topics.each do |topic|
          topic.except!(:category, :after_create)
          update_topic(topic)
        end
      end
    end

    private

    def topics(include_welcome_topics = true)
      staff_category = Category.find_by(id: SiteSetting.staff_category_id)

      topics = [
        # Terms of Service
        {
          site_setting_name: 'tos_topic_id',
          title: I18n.t('tos_topic.title'),
          raw: I18n.t('tos_topic.body',
                      company_name: setting_value('company_name'),
                      base_url: Discourse.base_url,
                      contact_email: setting_value('contact_email'),
                      governing_law: setting_value('governing_law'),
                      city_for_disputes: setting_value('city_for_disputes')
          ),
          category: staff_category,
          static_first_reply: true
        },

        # FAQ/Guidelines
        {
          site_setting_name: 'guidelines_topic_id',
          title: I18n.t('guidelines_topic.title'),
          raw: I18n.t('guidelines_topic.body', base_path: Discourse.base_path),
          category: staff_category,
          static_first_reply: true
        },

        # Privacy Policy
        {
          site_setting_name: 'privacy_topic_id',
          title: I18n.t('privacy_topic.title'),
          raw: I18n.t('privacy_topic.body'),
          category: staff_category,
          static_first_reply: true
        }
      ]

      if include_welcome_topics
        # Welcome Topic
        topics << {
          site_setting_name: 'welcome_topic_id',
          title: I18n.t('discourse_welcome_topic.title'),
          raw: I18n.t('discourse_welcome_topic.body', base_path: Discourse.base_path),
          after_create: proc do |post|
            post.topic.update_pinned(true, true)
          end
        }

        # Lounge Welcome Topic
        if lounge_category = Category.find_by(id: SiteSetting.lounge_category_id)
          topics << {
            site_setting_name: 'lounge_welcome_topic_id',
            title: I18n.t('lounge_welcome.title'),
            raw: I18n.t('lounge_welcome.body', base_path: Discourse.base_path),
            category: lounge_category,
            after_create: proc do |post|
              post.topic.update_pinned(true)
            end
          }
        end

        # Admin Quick Start Guide
        topics << {
          site_setting_name: 'admin_quick_start_topic_id',
          title: DiscoursePluginRegistry.seed_data['admin_quick_start_title'] || I18n.t('admin_quick_start_title'),
          raw: admin_quick_start_raw,
          category: staff_category
        }
      end

      topics
    end

    def create_topic(site_setting_name:, title:, raw:, category: nil, static_first_reply: false, after_create: nil)
      topic_id = SiteSetting.send(site_setting_name)
      return if topic_id > 0 || Topic.find_by(id: topic_id)

      post = PostCreator.create!(
        Discourse.system_user,
        title: title,
        raw: raw,
        skip_validations: true,
        category: category&.name
      )

      if static_first_reply
        PostCreator.create!(
          Discourse.system_user,
          raw: first_reply_raw(title),
          skip_validations: true,
          topic_id: post.topic_id
        )
      end

      after_create&.call(post)

      SiteSetting.send("#{site_setting_name}=", post.topic_id)
    end

    def update_topic(site_setting_name:, title:, raw:, static_first_reply: false)
      topic_id = SiteSetting.send(site_setting_name)
      post = Post.find_by(topic_id: topic_id, post_number: 1)
      return if !post

      post.revise(
        Discourse.system_user,
        title: title,
        raw: raw,
        skip_validations: true
      )

      if static_first_reply && reply = first_reply(post)
        reply.revise(
          Discourse.system_user,
          raw: first_reply_raw(title),
          skip_validations: true
        )
      end
    end

    def setting_value(site_setting_key)
      SiteSetting.send(site_setting_key).presence || "<ins>#{site_setting_key}</ins>"
    end

    def first_reply(post)
      Post.find_by(topic_id: post.topic_id, post_number: 2, user_id: Discourse::SYSTEM_USER_ID)
    end

    def first_reply_raw(topic_title)
      I18n.t('static_topic_first_reply', page_name: topic_title)
    end

    def admin_quick_start_raw
      quick_start_filename = DiscoursePluginRegistry.seed_data["admin_quick_start_filename"]

      if !quick_start_filename || !File.exist?(quick_start_filename)
        # TODO Make the quick start guide translatable
        quick_start_filename = File.join(Rails.root, 'docs', 'ADMIN-QUICK-START-GUIDE.md')
      end

      File.read(quick_start_filename)
    end
  end
end
