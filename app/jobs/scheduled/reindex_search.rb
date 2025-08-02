# frozen_string_literal: true

module Jobs
  class ReindexSearch < ::Jobs::Scheduled
    every 2.hours

    def execute(args)
      @verbose = args[:verbose]
      @cleanup_grace_period = 1.day.ago

      rebuild_categories
      rebuild_tags
      rebuild_topics
      rebuild_posts
      rebuild_users

      clean_topics
      clean_posts
    end

    def rebuild_categories(limit: 500, indexer: SearchIndexer)
      category_ids = load_problem_category_ids(limit)

      puts "rebuilding #{category_ids.size} categories" if @verbose

      category_ids.each do |id|
        category = Category.find_by(id: id)
        indexer.index(category, force: true) if category
      end
    end

    def rebuild_tags(limit: 1_000, indexer: SearchIndexer)
      tag_ids = load_problem_tag_ids(limit)

      puts "rebuilding #{tag_ids.size} tags" if @verbose

      tag_ids.each do |id|
        tag = Tag.find_by(id: id)
        indexer.index(tag, force: true) if tag
      end
    end

    def rebuild_topics(limit: 10_000, indexer: SearchIndexer)
      topic_ids = load_problem_topic_ids(limit)

      puts "rebuilding #{topic_ids.size} topics" if @verbose

      topic_ids.each do |id|
        topic = Topic.find_by(id: id)
        indexer.index(topic, force: true) if topic
      end
    end

    def rebuild_posts(limit: 20_000, indexer: SearchIndexer)
      post_ids = load_problem_post_ids(limit)

      puts "rebuilding #{post_ids.size} posts" if @verbose

      post_ids.each do |id|
        post = Post.find_by(id: id)
        indexer.index(post, force: true) if post
      end
    end

    def rebuild_users(limit: 5_000, indexer: SearchIndexer)
      user_ids = load_problem_user_ids(limit)

      puts "rebuilding #{user_ids.size} users" if @verbose

      user_ids.each do |id|
        user = User.find_by(id: id)
        indexer.index(user, force: true) if user
      end
    end

    def clean_topics
      puts "cleaning up topic search data" if @verbose

      # remove search data from deleted topics

      DB.exec(<<~SQL, deleted_at: @cleanup_grace_period)
        DELETE FROM topic_search_data
         WHERE topic_id IN (
          SELECT topic_id
            FROM topic_search_data
       LEFT JOIN topics ON topic_id = topics.id
           WHERE topics.id IS NULL
              OR (deleted_at IS NOT NULL AND deleted_at <= :deleted_at)
          )
      SQL
    end

    def clean_posts
      puts "cleaning up post search data" if @verbose

      # remove search data from deleted/empty posts

      DB.exec(<<~SQL, deleted_at: @cleanup_grace_period)
        DELETE FROM post_search_data
         WHERE post_id IN (
          SELECT post_id
            FROM post_search_data
       LEFT JOIN posts ON post_id = posts.id
            JOIN topics ON posts.topic_id = topics.id
           WHERE posts.id IS NULL
              OR posts.raw = ''
              OR (posts.deleted_at IS NOT NULL AND posts.deleted_at <= :deleted_at)
              OR (topics.deleted_at IS NOT NULL AND topics.deleted_at <= :deleted_at)
          )
      SQL
    end

    def load_problem_category_ids(limit)
      Category
        .joins("LEFT JOIN category_search_data ON category_id = categories.id")
        .where(
          "category_search_data.locale IS NULL OR category_search_data.locale != ? OR category_search_data.version != ?",
          SiteSetting.default_locale,
          SearchIndexer::CATEGORY_INDEX_VERSION,
        )
        .order("categories.id ASC")
        .limit(limit)
        .pluck(:id)
    end

    def load_problem_tag_ids(limit)
      Tag
        .joins("LEFT JOIN tag_search_data ON tag_id = tags.id")
        .where(
          "tag_search_data.locale IS NULL OR tag_search_data.locale != ? OR tag_search_data.version != ?",
          SiteSetting.default_locale,
          SearchIndexer::TAG_INDEX_VERSION,
        )
        .order("tags.id ASC")
        .limit(limit)
        .pluck(:id)
    end

    def load_problem_topic_ids(limit)
      Topic
        .joins("LEFT JOIN topic_search_data ON topic_id = topics.id")
        .where(
          "topic_search_data.locale IS NULL OR topic_search_data.locale != ? OR topic_search_data.version != ?",
          SiteSetting.default_locale,
          SearchIndexer::TOPIC_INDEX_VERSION,
        )
        .order("topics.id DESC")
        .limit(limit)
        .pluck(:id)
    end

    def load_problem_post_ids(limit)
      Post
        .joins(:topic)
        .joins("LEFT JOIN post_search_data ON post_id = posts.id")
        .where("posts.raw != ''")
        .where("topics.deleted_at IS NULL")
        .where(
          "post_search_data.locale IS NULL OR post_search_data.locale != ? OR post_search_data.version != ?",
          SiteSetting.default_locale,
          SearchIndexer::POST_INDEX_VERSION,
        )
        .order("posts.id DESC")
        .limit(limit)
        .pluck(:id)
    end

    def load_problem_user_ids(limit)
      User
        .joins("LEFT JOIN user_search_data ON user_id = users.id")
        .where(
          "user_search_data.locale IS NULL OR user_search_data.locale != ? OR user_search_data.version != ?",
          SiteSetting.default_locale,
          SearchIndexer::USER_INDEX_VERSION,
        )
        .order("users.id ASC")
        .limit(limit)
        .pluck(:id)
    end
  end
end
