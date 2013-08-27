require_dependency 'search/search_result'
require_dependency 'search/search_result_type'
require_dependency 'search/grouped_search_results'

class Search

  def self.per_facet
    5
  end

  # Sometimes we want more topics than are returned due to exclusion of dupes. This is the
  # factor of extra results we'll ask for.
  def self.burst_factor
    3
  end

  def self.facets
    %w(topic category user)
  end

  def self.long_locale
    case I18n.locale         # Currently-present in /conf/locales/* only, sorry :-( Add as needed
      when :da then 'danish'
      when :de then 'german'
      when :en then 'english'
      when :es then 'spanish'
      when :fr then 'french'
      when :it then 'italian'
      when :nl then 'dutch'
      when :pt then 'portuguese'
      when :sv then 'swedish'
      when :ru then 'russian'
      else 'simple' # use the 'simple' stemmer for other languages
    end
  end

  def initialize(term, opts=nil)
    if term.present?
      @term = term.to_s
      @original_term = PG::Connection.escape_string(@term)
    end

    @opts = opts || {}
    @guardian = @opts[:guardian] || Guardian.new
    @search_context = @opts[:search_context]
    @limit = Search.per_facet * Search.facets.size
    @results = GroupedSearchResults.new(@opts[:type_filter])
  end

  # Query a term
  def execute
    return nil if @term.blank? || @term.length < (@opts[:min_search_term_length] || SiteSetting.min_search_term_length)

    # If the term is a number or url to a topic, just include that topic
    if @results.type_filter == 'topic'
      begin
        route = Rails.application.routes.recognize_path(@term)
        return single_topic(route[:topic_id]).as_json if route[:topic_id].present?
      rescue ActionController::RoutingError
      end

      return single_topic(@term.to_i).as_json if @term =~ /^\d+$/
    end

    find_grouped_results.as_json
  end

  private

    def find_grouped_results

      if @results.type_filter.present?
        raise Discourse::InvalidAccess.new("invalid type filter") unless Search.facets.include?(@results.type_filter)
        send("#{@results.type_filter}_search")
      else
        @limit = Search.per_facet + 1
        user_search
        category_search
        topic_search
      end

      add_more_topics_if_expected
      @results
    end

    # Add more topics if we expected them
    def add_more_topics_if_expected
      expected_topics = 0
      expected_topics = Search.facets.size unless @results.type_filter.present?
      expected_topics = Search.per_facet * Search.facets.size if @results.type_filter == 'topic'
      expected_topics -= @results.topic_count
      if expected_topics > 0
        extra_posts = posts_query(expected_topics * Search.burst_factor)
        extra_posts = extra_posts.where("posts.topic_id NOT in (?)", @results.topic_ids) if @results.topic_ids.present?
        extra_posts.each do |p|
          @results.add_result(SearchResult.from_post(p))
        end
      end
    end

    # If we're searching for a single topic
    def single_topic(id)
      topic = Topic.where(id: id).first
      return nil unless @guardian.can_see?(topic)

      @results.add_result(SearchResult.from_topic(topic))
      @results
    end

    def secure_category_ids
      return @secure_category_ids unless @secure_category_ids.nil?
      @secure_category_ids = @guardian.secure_category_ids
    end

    def category_search
      categories = Category.includes(:category_search_data)
                           .where("category_search_data.search_data @@ #{ts_query}")
                           .references(:category_search_data)
                           .order("topics_month DESC")
                           .secured(@guardian)
                           .limit(@limit)

      categories.each do |c|
        @results.add_result(SearchResult.from_category(c))
      end
    end

    def user_search
      users = User.includes(:user_search_data)
                  .where("user_search_data.search_data @@ #{ts_query}")
                  .order("CASE WHEN username_lower = '#{@original_term.downcase}' THEN 0 ELSE 1 END")
                  .order("last_posted_at DESC")
                  .limit(@limit)
                  .references(:user_search_data)

      users.each do |u|
        @results.add_result(SearchResult.from_user(u))
      end
    end

    def posts_query(limit)
      posts = Post.includes(:post_search_data, {:topic => :category})
                  .where("post_search_data.search_data @@ #{ts_query}")
                  .where("topics.deleted_at" => nil)
                  .where("topics.visible")
                  .where("topics.archetype <> ?", Archetype.private_message)
                  .references(:post_search_data, {:topic => :category})

      # If we have a search context, prioritize those posts first
      if @search_context.present?

        if @search_context.is_a?(User)
          # If the context is a user, prioritize that user's posts
          posts = posts.order("CASE WHEN posts.user_id = #{@search_context.id} THEN 0 ELSE 1 END")
        elsif @search_context.is_a?(Category)
          # If the context is a category, restrict posts to that category
          posts = posts.order("CASE WHEN topics.category_id = #{@search_context.id} THEN 0 ELSE 1 END")
        end

      end

      posts = posts.order("TS_RANK_CD(TO_TSVECTOR(#{query_locale}, topics.title), #{ts_query}) DESC")
                   .order("TS_RANK_CD(post_search_data.search_data, #{ts_query}) DESC")
                   .order("topics.bumped_at DESC")

      if secure_category_ids.present?
        posts = posts.where("(categories.id IS NULL) OR (NOT categories.read_restricted) OR (categories.id IN (?))", secure_category_ids).references(:categories)
      else
        posts = posts.where("(categories.id IS NULL) OR (NOT categories.read_restricted)").references(:categories)
      end
      posts.limit(limit)
    end

    def query_locale
      @query_locale ||= Post.sanitize(Search.long_locale)
    end

    def ts_query
      @ts_query ||= begin
        all_terms = @term.gsub(/[:()&!'"]/,'').split
        query = Post.sanitize(all_terms.map {|t| "#{PG::Connection.escape_string(t)}:*"}.join(" & "))
        "TO_TSQUERY(#{query_locale}, #{query})"
      end
    end

    def topic_search

      # If we have a user filter, search all posts by default with a higher limit
      posts = if @search_context.present? and @search_context.is_a?(User)
        posts_query(@limit * Search.burst_factor)
      else
        posts_query(@limit).where(post_number: 1)
      end

      posts.each do |p|
        @results.add_result(SearchResult.from_post(p))
      end
    end

end
