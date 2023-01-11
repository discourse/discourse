# frozen_string_literal: true

require "discourse_dev/record"
require "faker"

module DiscourseDev
  class Post < Record
    attr_reader :topic

    def initialize(topic, count)
      super(::Post, count)
      @topic = topic

      category = topic.category
      @max_likes_count = DiscourseDev.config.post[:max_likes_count]
      if category&.groups.present?
        group_ids = category.groups.pluck(:id)
        @user_ids = ::GroupUser.where(group_id: group_ids).pluck(:user_id)
        @user_count = @user_ids.count
        @max_likes_count = @user_count - 1
      end
    end

    def data
      {
        topic_id: topic.id,
        raw: Faker::DiscourseMarkdown.sandwich(sentences: 5),
        created_at: Faker::Time.between(from: topic.last_posted_at, to: DateTime.now),
        skip_validations: true,
        skip_guardian: true,
      }
    end

    def create!
      user = self.user
      data = Faker::DiscourseMarkdown.with_user(user.id) { self.data }
      post = PostCreator.new(user, data).create!
      topic.reload
      generate_likes(post)
      post
    end

    def generate_likes(post)
      user_ids = [post.user_id]

      Faker::Number
        .between(from: 0, to: @max_likes_count)
        .times do
          user = self.user
          next if user_ids.include?(user.id)

          PostActionCreator.new(
            user,
            post,
            PostActionType.types[:like],
            created_at: Faker::Time.between(from: post.created_at, to: DateTime.now),
          ).perform
          user_ids << user.id
        end
    end

    def user
      return User.random if topic.category&.groups.blank?
      return Discourse.system_user if @user_ids.blank?

      position = Faker::Number.between(from: 0, to: @user_count - 1)
      ::User.find(@user_ids[position])
    end

    def populate!
      generate_likes(topic.first_post)

      super(ignore_current_count: true)
    end

    def current_count
      topic.posts_count - 1
    end

    def self.add_replies!(args)
      if !args[:topic_id]
        puts "Topic ID is required. Aborting."
        return
      end

      if !::Topic.find_by_id(args[:topic_id])
        puts "Topic ID does not match topic in DB, aborting."
        return
      end

      topic = ::Topic.find_by_id(args[:topic_id])
      count = args[:count] ? args[:count].to_i : 50

      puts "Creating #{count} replies in '#{topic.title}'"

      count.times do |i|
        begin
          user = User.random
          reply =
            Faker::DiscourseMarkdown.with_user(user.id) do
              {
                topic_id: topic.id,
                raw: Faker::DiscourseMarkdown.sandwich(sentences: 5),
                skip_validations: true,
              }
            end
          PostCreator.new(user, reply).create!
        rescue ActiveRecord::RecordNotSaved => e
          puts e
        end
      end

      puts "Done!"
    end

    def self.random
      super(::Post)
    end
  end
end
