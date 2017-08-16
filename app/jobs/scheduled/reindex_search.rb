module Jobs
  # if locale changes or search algorithm changes we may want to reindex stuff
  class ReindexSearch < Jobs::Scheduled
    every 1.day

    def execute(args)
      rebuild_problem_topics
      rebuild_problem_posts
      rebuild_problem_categories
      rebuild_problem_users
    end

    def rebuild_problem_categories(limit = 10000)
      categories = load_problem_categories(limit)

      categories.each do |category|
        SearchIndexer.index(category, force: true)
      end
    end

    def rebuild_problem_users(limit = 10000)
      users = load_problem_users(limit)

      users.each do |user|
        SearchIndexer.index(user, force: true)
      end
    end

    def rebuild_problem_topics(limit = 10000)
      topics = load_problem_topics(limit)

      topics.each do |topic|
        SearchIndexer.index(topic, force: true)
      end
    end

    def rebuild_problem_posts(limit = 10000)
      posts = load_problem_posts(limit)

      posts.each do |post|
        SearchIndexer.index(post, force: true)
      end
    end

    private

    def load_problem_posts(limit)
      Post.joins(:topic)
        .where('posts.id IN (
                SELECT p2.id FROM posts p2
                LEFT JOIN post_search_data pd ON pd.locale = ? AND pd.version = ? AND p2.id = pd.post_id
                WHERE pd.post_id IS NULL
                )', SiteSetting.default_locale, Search::INDEX_VERSION)
        .limit(limit)
    end

    def load_problem_categories(limit)
      Category.joins(:category_search_data)
        .where('category_search_data.locale != ?
                OR category_search_data.version != ?', SiteSetting.default_locale, Search::INDEX_VERSION)
        .limit(limit)
    end

    def load_problem_topics(limit)
      Topic.joins(:topic_search_data)
        .where('topic_search_data.locale != ?
                OR topic_search_data.version != ?', SiteSetting.default_locale, Search::INDEX_VERSION)
        .limit(limit)
    end

    def load_problem_users(limit)
      User.joins(:user_search_data)
        .where('user_search_data.locale != ?
                OR user_search_data.version != ?', SiteSetting.default_locale, Search::INDEX_VERSION)
        .limit(limit)
    end
  end
end
