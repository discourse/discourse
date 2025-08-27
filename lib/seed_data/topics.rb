# frozen_string_literal: true

module SeedData
  class Topics
    def self.with_default_locale
      SeedData::Topics.new(SiteSetting.default_locale)
    end

    def initialize(locale)
      @locale = locale
    end

    def create(site_setting_names: nil, include_welcome_topics: true, include_legal_topics: false)
      I18n.with_locale(@locale) do
        topics(
          site_setting_names: site_setting_names,
          include_welcome_topics: include_welcome_topics,
          include_legal_topics: include_legal_topics || SiteSetting.company_name.present?,
        ).each { |params| create_topic(**params) }
      end
    end

    def update(site_setting_names: nil, skip_changed: false)
      I18n.with_locale(@locale) do
        topics(
          site_setting_names: site_setting_names,
          require_existing_categories: false,
        ).each do |params|
          update_topic(**params.except(:category, :after_create), skip_changed: skip_changed)
        end
      end
    end

    def delete(site_setting_names: nil, skip_changed: false)
      I18n.with_locale(@locale) do
        topics(site_setting_names: site_setting_names).each do |params|
          delete_topic(**params.slice(:site_setting_name), skip_changed: skip_changed)
        end
      end
    end

    def reseed_options
      I18n.with_locale(@locale) do
        topics(require_existing_categories: false)
          .map do |params|
            post = find_post(params[:site_setting_name])
            next unless post

            { id: params[:site_setting_name], name: post.topic.title, selected: unchanged?(post) }
          end
          .compact
      end
    end

    private

    def topics(
      site_setting_names: nil,
      include_welcome_topics: true,
      include_legal_topics: true,
      require_existing_categories: true
    )
      general_category = Category.find_by(id: SiteSetting.general_category_id)
      staff_category = Category.find_by(id: SiteSetting.staff_category_id)
      feedback_category = Category.find_by(id: SiteSetting.meta_category_id)
      feedback_category_hashtag =
        feedback_category ? "##{feedback_category.slug}" : "#site-feedback"

      topics = []

      # Terms of Service
      if include_legal_topics
        topics << {
          site_setting_name: "tos_topic_id",
          title: I18n.t("tos_topic.title"),
          raw:
            I18n.t(
              "tos_topic.body",
              company_name: setting_value("company_name"),
              base_url: Discourse.base_url,
              contact_email: setting_value("contact_email"),
              governing_law: setting_value("governing_law"),
              city_for_disputes: setting_value("city_for_disputes"),
            ),
          category: staff_category,
          static_first_reply: true,
        }
      end

      # FAQ/Guidelines
      topics << {
        site_setting_name: "guidelines_topic_id",
        title:
          (
            if SiteSetting.experimental_rename_faq_to_guidelines
              I18n.t("guidelines_topic.guidelines_title")
            else
              I18n.t("guidelines_topic.title")
            end
          ),
        raw:
          I18n.t(
            "guidelines_topic.body",
            base_path: Discourse.base_path,
            feedback_category: feedback_category_hashtag,
          ),
        category: staff_category,
        static_first_reply: true,
      }

      # Privacy Policy
      if include_legal_topics
        topics << {
          site_setting_name: "privacy_topic_id",
          title: I18n.t("privacy_topic.title"),
          raw: I18n.t("privacy_topic.body"),
          category: staff_category,
          static_first_reply: true,
        }
      end

      if include_welcome_topics
        # Welcome Topic
        if general_category || !require_existing_categories
          site_info_quote =
            if SiteSetting.title.present? && SiteSetting.site_description.present?
              <<~RAW
              > ## #{SiteSetting.title}
              >
              > #{SiteSetting.site_description}
              RAW
            else
              ""
            end

          topics << {
            site_setting_name: "welcome_topic_id",
            title: I18n.t("discourse_welcome_topic.title", site_title: SiteSetting.title),
            raw:
              I18n.t(
                "discourse_welcome_topic.body",
                base_path: Discourse.base_path,
                site_title: SiteSetting.title,
                site_description: SiteSetting.site_description,
                site_info_quote: site_info_quote,
                feedback_category: feedback_category_hashtag,
              ),
            category: general_category,
            after_create: proc { |post| post.topic.update_pinned(true, true) },
          }
        end

        # Admin Quick Start Guide
        topics << {
          site_setting_name: "admin_quick_start_topic_id",
          title:
            DiscoursePluginRegistry.seed_data["admin_quick_start_title"] ||
              I18n.t("admin_quick_start_title"),
          raw: admin_quick_start_raw,
          category: staff_category,
        }
      end

      if site_setting_names
        topics.select! { |t| site_setting_names.include?(t[:site_setting_name]) }
      end

      topics
    end

    def create_topic(
      site_setting_name:,
      title:,
      raw:,
      category: nil,
      static_first_reply: false,
      after_create: nil
    )
      topic_id = SiteSetting.get(site_setting_name)
      return if topic_id > 0 || Topic.find_by(id: topic_id)

      post =
        PostCreator.create!(
          Discourse.system_user,
          title: title,
          raw: raw,
          skip_jobs: true,
          skip_validations: true,
          category: category&.id,
        )

      if static_first_reply
        PostCreator.create!(
          Discourse.system_user,
          raw: first_reply_raw(title),
          skip_jobs: true,
          skip_validations: true,
          topic_id: post.topic_id,
        )
      end

      after_create&.call(post)

      SiteSetting.set(site_setting_name, post.topic_id)
    end

    def update_topic(site_setting_name:, title:, raw:, static_first_reply: false, skip_changed:)
      post = find_post(site_setting_name, deleted: true)
      return if !post

      if !skip_changed || unchanged?(post)
        if post.trashed?
          PostDestroyer.new(
            Discourse.system_user,
            post,
            context: I18n.t("staff_action_logs.seed_data_topic_updated"),
          ).recover
          post.reload
        end

        post.revise(Discourse.system_user, { title: title, raw: raw }, skip_validations: true)
      end

      if static_first_reply && (reply = first_reply(post)) && (!skip_changed || unchanged?(reply))
        reply.revise(Discourse.system_user, { raw: first_reply_raw(title) }, skip_validations: true)
      end
    end

    def delete_topic(site_setting_name:, skip_changed:)
      post = find_post(site_setting_name)
      return if !post

      if !skip_changed || unchanged?(post)
        PostDestroyer.new(
          Discourse.system_user,
          post,
          context: I18n.t("staff_action_logs.seed_data_topic_deleted"),
        ).destroy
      end
    end

    def find_post(site_setting_name, deleted: false)
      topic_id = SiteSetting.get(site_setting_name)
      return if topic_id < 1

      posts = Post.where(topic_id: topic_id, post_number: 1)
      posts = posts.with_deleted if deleted
      posts.first
    end

    def unchanged?(post)
      post.last_editor_id == Discourse::SYSTEM_USER_ID &&
        (!post.deleted_by_id || post.deleted_by_id == Discourse::SYSTEM_USER_ID)
    end

    def setting_value(site_setting_key)
      SiteSetting.get(site_setting_key).presence || "<ins>#{site_setting_key}</ins>"
    end

    def first_reply(post)
      Post.find_by(topic_id: post.topic_id, post_number: 2, user_id: Discourse::SYSTEM_USER_ID)
    end

    def first_reply_raw(topic_title)
      I18n.t("static_topic_first_reply", page_name: topic_title)
    end

    def admin_quick_start_raw
      quick_start_filename = DiscoursePluginRegistry.seed_data["admin_quick_start_filename"]

      if !quick_start_filename || !File.exist?(quick_start_filename)
        # TODO Make the quick start guide translatable
        quick_start_filename = File.join(Rails.root, "docs", "ADMIN-QUICK-START-GUIDE.md")
      end

      content = File.read(quick_start_filename)
      content.gsub!("%{base_url}", Discourse.base_url)
      content
    end
  end
end
