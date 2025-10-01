# frozen_string_literal: true

module DiscourseAi
  module Automation
    class ReportContextGenerator
      def self.generate(**args)
        new(**args).generate
      end

      def initialize(
        start_date:,
        duration:,
        category_ids: nil,
        tags: nil,
        allow_secure_categories: false,
        max_posts: 200,
        tokens_per_post: 100,
        tokenizer: nil,
        prioritized_group_ids: [],
        exclude_category_ids: nil,
        exclude_tags: nil
      )
        @start_date = start_date
        @duration = duration
        @category_ids = category_ids
        @tags = tags
        @allow_secure_categories = allow_secure_categories
        @max_posts = max_posts
        @tokenizer = tokenizer || DiscourseAi::Tokenizer::OpenAiTokenizer
        @tokens_per_post = tokens_per_post
        @prioritized_group_ids = prioritized_group_ids

        @posts =
          Post
            .where("posts.created_at >= ?", @start_date)
            .joins(topic: :category)
            .includes(:topic, :user)
            .where("topics.visible")
            .where("posts.created_at < ?", @start_date + @duration)
            .where("posts.post_type = ?", Post.types[:regular])
            .where("posts.hidden_at IS NULL")
            .where("topics.deleted_at IS NULL")
            .where("topics.archetype = ?", Archetype.default)
        @posts = @posts.where("categories.read_restricted = ?", false) if !@allow_secure_categories
        @posts = @posts.where("categories.id IN (?)", @category_ids) if @category_ids.present?
        @posts =
          @posts.where(
            "categories.id NOT IN (:ids) AND
            (parent_category_id NOT IN (:ids) OR parent_category_id IS NULL)",
            ids: exclude_category_ids,
          ) if exclude_category_ids.present?

        if exclude_tags.present?
          exclude_tag_ids = Tag.where_name(exclude_tags).select(:id)
          @posts =
            @posts.where(
              "topics.id NOT IN (?)",
              TopicTag.where(tag_id: exclude_tag_ids).select(:topic_id),
            )
        end

        if @tags.present?
          tag_ids = Tag.where_name(@tags).select(:id)
          topic_ids_with_tags = TopicTag.where(tag_id: tag_ids).select(:topic_id)
          @posts = @posts.where(topic_id: topic_ids_with_tags)
        end

        if defined?(DiscourseSolved)
          @solutions =
            DiscourseSolved::SolvedTopic
              .where(topic_id: @posts.select(:topic_id))
              .pluck(:topic_id, :answer_post_id)
              .to_h
        else
          @solutions = {}
        end
      end

      def format_topic(topic)
        info = []
        info << ""
        info << "### #{topic.title}"
        info << "topic_id: #{topic.id}"
        info << "solved: true" if @solutions.key?(topic.id)
        info << "category: #{topic.category&.name}"
        # We may make this optional, but for now we remove all
        # tags that are not visible to anon
        tags = topic.tags.visible(Guardian.new).pluck(:name)
        info << "tags: #{tags.join(", ")}" if tags.present?
        info << topic.created_at.strftime("%Y-%m-%d %H:%M")
        { created_at: topic.created_at, info: info.join("\n"), posts: {} }
      end

      def format_post(post)
        buffer = []
        buffer << ""
        buffer << "post_number: #{post.post_number}"
        buffer << "solution: true" if @solutions[post.topic_id] == post.id
        buffer << post.created_at.strftime("%Y-%m-%d %H:%M")
        buffer << "user: #{post.user&.username}"
        buffer << "likes: #{post.like_count}"
        excerpt =
          @tokenizer.truncate(
            post.raw,
            @tokens_per_post,
            strict: SiteSetting.ai_strict_token_counting,
          )
        excerpt = "excerpt: #{excerpt}..." if excerpt.length < post.raw.length
        buffer << "#{excerpt}"
        { likes: post.like_count, info: buffer.join("\n") }
      end

      def format_summary
        topic_count =
          @posts
            .where("topics.created_at > ?", @start_date)
            .select(:topic_id)
            .distinct(:topic_id)
            .count

        buffer = []
        buffer << "Start Date: #{@start_date.to_date}"
        buffer << "End Date: #{(@start_date + @duration).to_date}"
        buffer << "New posts: #{@posts.count}"
        buffer << "New topics: #{topic_count}"

        top_users =
          Post
            .where(id: @posts.select(:id))
            .joins(:user)
            .group(:user_id, :username)
            .select(
              "user_id, username, sum(posts.like_count) like_count, count(posts.id) post_count",
            )
            .order("sum(posts.like_count) desc")
            .limit(10)

        buffer << "Top users:"
        top_users.each do |user|
          buffer << "@#{user.username} (#{user.like_count} likes, #{user.post_count} posts)"
        end

        if @prioritized_group_ids.present?
          group_names =
            Group
              .where(id: @prioritized_group_ids)
              .pluck(:name, :full_name)
              .map do |name, full_name|
                if full_name.present?
                  "#{name} (#{full_name[0..100].gsub("\n", " ")})"
                else
                  name
                end
              end
              .join(", ")
          buffer << ""
          buffer << "Top users in #{group_names} group#{group_names.include?(",") ? "s" : ""}:"

          group_users = GroupUser.where(group_id: @prioritized_group_ids).select(:user_id)
          top_users
            .where(user_id: group_users)
            .each do |user|
              buffer << "@#{user.username} (#{user.like_count} likes, #{user.post_count} posts)"
            end
        end

        buffer.join("\n")
      end

      def format_topics
        buffer = []
        topics = {}

        post_count = 0

        @posts = @posts.order("posts.like_count desc, posts.created_at desc")

        if @prioritized_group_ids.present?
          user_groups = GroupUser.where(group_id: @prioritized_group_ids)
          prioritized_posts = @posts.where(user_id: user_groups.select(:user_id)).limit(@max_posts)

          post_count += add_posts(prioritized_posts, topics)
        end

        add_posts(@posts.limit(@max_posts), topics, limit: @max_posts - post_count)

        # we need last posts in all topics
        # they may have important info
        last_posts =
          @posts.where("posts.post_number = topics.highest_post_number").where(
            "topics.id IN (?)",
            topics.keys,
          )

        add_posts(last_posts, topics)

        topics.each do |topic_id, topic_info|
          topic_info[:post_likes] = topic_info[:posts].sum { |_, post_info| post_info[:likes] }
        end

        topics = topics.sort { |a, b| b[1][:post_likes] <=> a[1][:post_likes] }

        topics.each do |topic_id, topic_info|
          buffer << topic_info[:info]

          last_post_number = 0

          topic_info[:posts]
            .sort { |a, b| a[0] <=> b[0] }
            .each do |post_number, post_info|
              buffer << "\n..." if post_number > last_post_number + 1
              buffer << post_info[:info]
              last_post_number = post_number
            end
        end

        buffer.join("\n")
      end

      def generate
        buffer = []

        buffer << "## Summary"
        buffer << format_summary
        buffer << "\n## Topics"
        buffer << format_topics

        buffer.join("\n")
      end

      def add_posts(relation, topics, limit: nil)
        post_count = 0
        relation.each do |post|
          topics[post.topic_id] ||= format_topic(post.topic)
          if !topics[post.topic_id][:posts][post.post_number]
            topics[post.topic_id][:posts][post.post_number] = format_post(post)
            post_count += 1
            limit -= 1 if limit
          end
          break if limit && limit <= 0
        end
        post_count
      end
    end
  end
end
