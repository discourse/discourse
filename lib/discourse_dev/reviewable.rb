# frozen_string_literal: true

require "discourse_dev/record"
require "faker"

module DiscourseDev
  class Reviewable < Record
    def initialize(users, topics, posts)
      @users = users
      @topics = topics
      @posts = posts
    end

    def self.populate!
      users = create_needed_users(10)
      topics = create_needed_topics(5)
      posts = create_needed_posts(10, topics)

      (
        [ReviewableFlaggedPost, ReviewableQueuedPost, ReviewablePost, ReviewableUser] +
          DiscoursePluginRegistry.discourse_dev_populate_reviewable_types.to_a
      ).each { |klass| klass.new(users, topics, posts).populate! }
    end

    private

    def self.create_needed_users(count)
      users = ::User.human_users.limit(count).to_a

      (count - users.size).times { users << User.new.create! } if users.size < count

      users
    end

    def self.create_needed_topics(count)
      topics =
        ::Topic
          .listable_topics
          .where("id NOT IN (?)", ::Category.pluck(:topic_id))
          .limit(count)
          .to_a

      (count - topics.size).times { topics << Topic.new.create! } if topics.size < count

      topics
    end

    def self.create_needed_posts(count, topics)
      per_topic = count / topics.size

      posts = []
      topics.each do |topic|
        current_count = topic.posts.where("post_number > 1").count

        (count - current_count).times { Post.new(topic, 1).create! } if current_count < count
        posts.push(*topic.posts.where("post_number > 1").limit(per_topic).to_a)
      end

      posts
    end
  end
end
