# frozen_string_literal: true

module Jobs
  # if locale changes or search algorithm changes we may want to reindex stuff
  class ReindexSearch < ::Jobs::Scheduled
    every 2.hours

    CLEANUP_GRACE_PERIOD ||= 1.day.ago

    def execute(args)
      rebuild_problem_topics
      rebuild_problem_posts
      rebuild_problem_categories
      rebuild_problem_users
      rebuild_problem_tags
      clean_post_search_data
      clean_topic_search_data
    end

    def rebuild_problem_categories(limit: 500)
      category_ids = load_problem_category_ids(limit)

      category_ids.each do |id|
        category = Category.find_by(id: id)
        SearchIndexer.index(category, force: true) if category
      end
    end

    def rebuild_problem_users(limit: 10000)
      user_ids = load_problem_user_ids(limit)

      user_ids.each do |id|
        user = User.find_by(id: id)
        SearchIndexer.index(user, force: true) if user
      end
    end

    def rebuild_problem_topics(limit: 10000)
      topic_ids = load_problem_topic_ids(limit)

      topic_ids.each do |id|
        topic = Topic.find_by(id: id)
        SearchIndexer.index(topic, force: true) if topic
      end
    end

    def rebuild_problem_posts(limit: 20000, indexer: SearchIndexer)
      post_ids = load_problem_post_ids(limit)

      post_ids.each do |id|
        # could be deleted while iterating through batch
        if post = Post.find_by(id: id)
          indexer.index(post, force: true)
        end
      end
    end

    def rebuild_problem_tags(limit: 10000)
      tag_ids = load_problem_tag_ids(limit)

      tag_ids.each do |id|
        tag = Tag.find_by(id: id)
        SearchIndexer.index(tag, force: true) if tag
      end
    end

    private

    def clean_post_search_data
      PostSearchData
        .joins("LEFT JOIN posts p ON p.id = post_search_data.post_id")
        .where("p.raw = ''")
        .delete_all

      DB.exec(<<~SQL, deleted_at: CLEANUP_GRACE_PERIOD)
        DELETE FROM post_search_data
        WHERE post_id IN (
          SELECT post_id
          FROM post_search_data
          LEFT JOIN posts ON post_search_data.post_id = posts.id
          INNER JOIN topics ON posts.topic_id = topics.id
          WHERE (topics.deleted_at IS NOT NULL
          AND topics.deleted_at <= :deleted_at) OR (
            posts.deleted_at IS NOT NULL AND
            posts.deleted_at <= :deleted_at
          )

        )
      SQL
    end

    def clean_topic_search_data
      DB.exec(<<~SQL, deleted_at: CLEANUP_GRACE_PERIOD)
      DELETE FROM topic_search_data
      WHERE topic_id IN (
        SELECT topic_id
        FROM topic_search_data
        INNER JOIN topics ON topic_search_data.topic_id = topics.id
        WHERE topics.deleted_at IS NOT NULL
        AND topics.deleted_at <= :deleted_at
      )
      SQL
    end

    def load_problem_post_ids(limit)
      params = {
        locale: SiteSetting.default_locale,
        version: SearchIndexer::INDEX_VERSION,
        limit: limit
      }

      DB.query_single(<<~SQL, params)
        SELECT
          posts.id
        FROM posts
        LEFT JOIN post_search_data pd
          ON pd.locale = :locale
          AND pd.version = :version
          AND pd.post_id = posts.id
        INNER JOIN topics ON topics.id = posts.topic_id
        WHERE pd.post_id IS NULL
        AND posts.deleted_at IS NULL
        AND topics.deleted_at IS NULL
        AND posts.raw != ''
        ORDER BY posts.id DESC
        LIMIT :limit
      SQL
    end

    def load_problem_category_ids(limit)
      Category.joins(:category_search_data)
        .where('category_search_data.locale != ?
                OR category_search_data.version != ?', SiteSetting.default_locale, SearchIndexer::INDEX_VERSION)
        .order('categories.id asc')
        .limit(limit)
        .pluck(:id)
    end

    def load_problem_topic_ids(limit)
      Topic.joins(:topic_search_data)
        .where('topic_search_data.locale != ?
                OR topic_search_data.version != ?', SiteSetting.default_locale, SearchIndexer::INDEX_VERSION)
        .order('topics.id desc')
        .limit(limit)
        .pluck(:id)
    end

    def load_problem_user_ids(limit)
      User.joins(:user_search_data)
        .where('user_search_data.locale != ?
                OR user_search_data.version != ?', SiteSetting.default_locale, SearchIndexer::INDEX_VERSION)
        .order('users.id asc')
        .limit(limit)
        .pluck(:id)
    end

    def load_problem_tag_ids(limit)
      Tag.joins(:tag_search_data)
        .where('tag_search_data.locale != ?
                OR tag_search_data.version != ?', SiteSetting.default_locale, SearchIndexer::INDEX_VERSION)
        .order('tags.id asc')
        .limit(limit)
        .pluck(:id)
    end
  end
end
