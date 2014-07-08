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
    # if adding a language see:
    # /usr/share/postgresql/9.3/tsearch_data for possible options
    # Do not add languages that are missing without amending the
    # base docker config
    #
    case SiteSetting.default_locale.to_sym
      when :da     then 'danish'
      when :de     then 'german'
      when :en     then 'english'
      when :es     then 'spanish'
      when :fr     then 'french'
      when :it     then 'italian'
      when :nl     then 'dutch'
      when :nb_NO  then 'norwegian'
      when :pt     then 'portuguese'
      when :pt_BR  then 'portuguese'
      when :sv     then 'swedish'
      when :ru     then 'russian'
      else 'simple' # use the 'simple' stemmer for other languages
    end
  end

  def self.rebuild_problem_posts(limit = 10000)
    posts = Post.joins(:topic)
            .where('posts.id IN (
               SELECT p2.id FROM posts p2
               LEFT JOIN post_search_data pd ON locale = ? AND p2.id = pd.post_id
               WHERE pd.post_id IS NULL
              )', SiteSetting.default_locale).limit(10000)

    posts.each do |post|
      # force indexing
      post.cooked += " "
      SearchObserver.index(post)
    end

    nil
  end

  def self.prepare_data(search_data)
    data = search_data.squish
    # TODO rmmseg is designed for chinese, we need something else for Korean / Japanese
    if ['zh_TW', 'zh_CN', 'ja', 'ko'].include?(SiteSetting.default_locale)
      unless defined? RMMSeg
        require 'rmmseg'
        RMMSeg::Dictionary.load_dictionaries
      end

      algo = RMMSeg::Algorithm.new(search_data)

      data = ""
      while token = algo.next_token
        data << token.text << " "
      end
    end

    data.force_encoding("UTF-8")
    data
  end

  def initialize(term, opts=nil)
    if term.present?
      @term = Search.prepare_data(term.to_s)
      @original_term = PG::Connection.escape_string(@term)
    end

    @opts = opts || {}
    @guardian = @opts[:guardian] || Guardian.new
    @search_context = @opts[:search_context]
    @include_blurbs = @opts[:include_blurbs] || false
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
        unless @search_context
          user_search
          category_search
        end
        topic_search
      end

      add_more_topics_if_expected
      @results
    rescue ActiveRecord::StatementInvalid
      # In the event of a PG:Error return nothing, it is likely they used a foreign language whose
      # locale is not supported by postgres
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
          @results.add_result(SearchResult.from_post(p, @search_context, @term, @include_blurbs))
        end
      end
    end

    # If we're searching for a single topic
    def single_topic(id)
      topic = Topic.find_by(id: id)
      return nil unless @guardian.can_see?(topic)

      @results.add_result(SearchResult.from_topic(topic))
      @results
    end

    def secure_category_ids
      return @secure_category_ids unless @secure_category_ids.nil?
      @secure_category_ids = @guardian.secure_category_ids
    end

    def category_search
      # scope is leaking onto Category, this is not good and probably a bug in Rails
      # the secure_category_ids will invoke the same method on User, it calls Category.where
      # however the scope from the query below is leaking in to Category, this works around
      # the issue while we figure out what is up in Rails
      secure_category_ids

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
                  .where("user_search_data.search_data @@ #{ts_query("simple")}")
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
                  .where("topics.deleted_at" => nil)
                  .where("topics.visible")
                  .where("topics.archetype <> ?", Archetype.private_message)
                  .references(:post_search_data, {:topic => :category})

      if @search_context.present? && @search_context.is_a?(Topic)
        posts = posts.where("posts.raw ilike ?", "%#{@term}%")
      else
        posts = posts.where("post_search_data.search_data @@ #{ts_query}")
      end

      # If we have a search context, prioritize those posts first
      if @search_context.present?

        if @search_context.is_a?(User)
          posts = posts.where("posts.user_id = #{@search_context.id}")
        elsif @search_context.is_a?(Category)
          posts = posts.where("topics.category_id = #{@search_context.id}")
        elsif @search_context.is_a?(Topic)
          posts = posts.where("topics.id = #{@search_context.id}")
                       .order("posts.post_number")
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

    def self.query_locale
      @query_locale ||= Post.sanitize(Search.long_locale)
    end

    def query_locale
      self.class.query_locale
    end

    def self.ts_query(term, locale = nil)
      locale = Post.sanitize(locale) if locale
      all_terms = term.gsub(/[:()&!'"]/,'').split
      query = Post.sanitize(all_terms.map {|t| "#{PG::Connection.escape_string(t)}:*"}.join(" & "))
      "TO_TSQUERY(#{locale || query_locale}, #{query})"
    end

    def ts_query(locale=nil)
      if !locale
        @ts_query ||= begin
          Search.ts_query(@term, locale)
        end
      else
        Search.ts_query(@term, locale)
      end
    end

    def topic_search

      posts = if @search_context.is_a?(User)
                # If we have a user filter, search all posts by default with a higher limit
                posts_query(@limit * Search.burst_factor)
              elsif @search_context.is_a?(Topic)
                posts_query(@limit).where('posts.post_number = 1 OR posts.topic_id = ?', @search_context.id)
              else
                posts_query(@limit).where(post_number: 1)
              end


      posts.each do |p|
        @results.add_result(SearchResult.from_post(p, @search_context, @term, @include_blurbs))
      end

    end

end
