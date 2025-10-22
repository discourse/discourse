# frozen_string_literal: true

require "discourse_dev/record"
require "faker"
require "sidekiq/api"

module DiscourseDev
  class Topic < Record
    def initialize(private_messages: false, recipient: nil, ignore_current_count: false)
      @settings = DiscourseDev.config.topic
      @private_messages = private_messages
      @recipient = recipient
      @ignore_current_count = ignore_current_count
      super(::Topic, @settings[:count])
    end

    def data
      max_views = 0

      case Faker::Number.between(from: 0, to: 5)
      when 0
        max_views = 10
      when 1
        max_views = 100
      when 2
        max_views = SiteSetting.topic_views_heat_low
      when 3
        max_views = SiteSetting.topic_views_heat_medium
      when 4
        max_views = SiteSetting.topic_views_heat_high
      when 5
        max_views = SiteSetting.topic_views_heat_high + SiteSetting.topic_views_heat_medium
      end

      if @category
        merge_attributes = { category: @category.id, tags: tags }
      else
        merge_attributes = { archetype: "private_message", target_usernames: [@recipient] }
      end

      {
        title: title[0, SiteSetting.max_topic_title_length],
        raw: Faker::DiscourseMarkdown.sandwich(sentences: 5),
        created_at: Faker::Time.between(from: DiscourseDev.config.start_date, to: DateTime.now),
        topic_opts: {
          import_mode: true,
          views: Faker::Number.between(from: 1, to: max_views),
          custom_fields: {
            dev_sample: true,
          },
        },
        skip_validations: true,
      }.merge(merge_attributes)
    end

    def title
      if current_count < I18n.t("faker.discourse.topics").count
        Faker::Discourse.unique.topic
      else
        Faker::Lorem
          .unique
          .sentence(word_count: 5, supplemental: true, random_words_to_add: 4)
          .chomp(".")
      end
    end

    def tags
      return unless SiteSetting.tagging_enabled

      @tags = []

      Faker::Number
        .between(from: @settings.dig(:tags, :min), to: @settings.dig(:tags, :max))
        .times { @tags << Faker::Discourse.tag }

      @tags.uniq
    end

    def create!
      if @private_messages && !::User.find_by_username(@recipient)
        puts "Cannot create PMs for missing user with username: #{@recipient}"
        exit 1
      end

      @category = @private_messages ? nil : Category.random

      user = self.user
      topic_data = Faker::DiscourseMarkdown.with_user(user.id) { data }
      post = PostCreator.new(user, topic_data).create!

      if override = @settings.dig(:replies, :overrides).find { |o| o[:title] == topic_data[:title] }
        reply_count = override[:count]
      else
        reply_count =
          Faker::Number.between(
            from: @settings.dig(:replies, :min),
            to: @settings.dig(:replies, :max),
          )
      end

      topic = post.topic
      Post.new(topic, reply_count).populate!
      topic
    end

    def populate!
      topics = super(ignore_current_count: @ignore_current_count)
      delete_unwanted_sidekiq_jobs
      topics
    end

    def user
      return ::User.find_by_username(@recipient) if @private_messages
      return User.random if @category.groups.blank?

      group_ids = @category.groups.pluck(:id)
      user_ids = ::GroupUser.where(group_id: group_ids).pluck(:user_id)
      user_count = user_ids.count
      position = Faker::Number.between(from: 0, to: user_count - 1)
      ::User.find(user_ids[position] || Discourse::SYSTEM_USER_ID)
    end

    def current_count
      category_definition_topic_ids = ::Category.pluck(:topic_id)
      ::Topic.where(archetype: :regular).where.not(id: category_definition_topic_ids).count
    end

    def delete_unwanted_sidekiq_jobs
      Sidekiq::ScheduledSet.new.each { |job| job.delete if job.item["class"] == "Jobs::UserEmail" }
    end
  end
end
