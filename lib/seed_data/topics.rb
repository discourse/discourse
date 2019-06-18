# frozen_string_literal: true

module SeedData
  class Topics
    def self.with_default_locale
      SeedData::Topics.new(SiteSetting.default_locale)
    end

    def initialize(locale)
      @locale = locale
    end

    def create(site_setting_names: nil, include_welcome_topics: true)
      I18n.with_locale(@locale) do
        topics(site_setting_names, include_welcome_topics).each do |params|
          create_topic(params)
        end
      end
    end

    def update(site_setting_names: nil, skip_changed: false)
      I18n.with_locale(@locale) do
        topics(site_setting_names).each do |params|
          params.except!(:category, :after_create)
          params[:skip_changed] = skip_changed
          update_topic(params)
        end
      end
    end

    def reseed_options
      I18n.with_locale(@locale) do
        topics.map do |params|
          post = find_post(params[:site_setting_name])
          next unless post

          {
            id: params[:site_setting_name],
            name: post.topic.title,
            selected: unchanged?(post)
          }
        end.compact
      end
    end

    private

    def topics(site_setting_names = nil, include_welcome_topics = true)
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

      if site_setting_names
        topics.select! { |t| site_setting_names.include?(t[:site_setting_name]) }
      end

      topics
    end

    def create_topic(site_setting_name:, title:, raw:, category: nil, static_first_reply: false, after_create: nil)
      topic_id = SiteSetting.get(site_setting_name)
      return if topic_id > 0 || Topic.find_by(id: topic_id)

      post = PostCreator.create!(
        Discourse.system_user,
        title: title,
        raw: raw,
        skip_validations: true,
        category: category&.id
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

      SiteSetting.set(site_setting_name, post.topic_id)
    end

    def update_topic(site_setting_name:, title:, raw:, static_first_reply: false, skip_changed:)
      post = find_post(site_setting_name)
      return if !post

      if !skip_changed || unchanged?(post)
        changes = { title: title, raw: raw }
        post.revise(Discourse.system_user, changes, skip_validations: true)
      end

      if static_first_reply && (reply = first_reply(post)) && (!skip_changed || unchanged?(reply))
        changes = { raw: first_reply_raw(title) }
        reply.revise(Discourse.system_user, changes, skip_validations: true)
      end
    end

    def find_post(site_setting_name)
      topic_id = SiteSetting.get(site_setting_name)
      Post.find_by(topic_id: topic_id, post_number: 1) if topic_id > 0
    end

    def unchanged?(post)
      post.last_editor_id == Discourse::SYSTEM_USER_ID
    end

    def setting_value(site_setting_key)
      SiteSetting.get(site_setting_key).presence || "<ins>#{site_setting_key}</ins>"
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
