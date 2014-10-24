require_dependency 'search/grouped_search_results'

class Search

  def self.per_facet
    5
  end

  def self.per_filter
    50
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

    posts = Post.joins(:topic)
            .where('posts.id IN (
               SELECT p2.id FROM posts p2
               LEFT JOIN topic_search_data pd ON locale = ? AND p2.topic_id = pd.topic_id
               WHERE pd.topic_id IS NULL AND p2.post_number = 1
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
    term = process_advanced_search!(term)
    if term.present?
      @term = Search.prepare_data(term.to_s)
      @original_term = PG::Connection.escape_string(@term)
    end

    @opts = opts || {}
    @guardian = @opts[:guardian] || Guardian.new
    @search_context = @opts[:search_context]
    @include_blurbs = @opts[:include_blurbs] || false
    @limit = Search.per_facet
    if @opts[:type_filter].present?
      @limit = Search.per_filter
    end

    @results = GroupedSearchResults.new(@opts[:type_filter], term, @search_context, @include_blurbs)
  end

  def self.execute(term, opts=nil)
    self.new(term, opts).execute
  end

  # Query a term
  def execute
    return nil if @term.blank? || @term.length < (@opts[:min_search_term_length] || SiteSetting.min_search_term_length)

    # If the term is a number or url to a topic, just include that topic
    if @opts[:search_for_id] && @results.type_filter == 'topic'
      if @term =~ /^\d+$/
        single_topic(@term.to_i)
      else
        begin
          route = Rails.application.routes.recognize_path(@term)
          single_topic(route[:topic_id]) if route[:topic_id].present?
        rescue ActionController::RoutingError
        end
      end
    end

    find_grouped_results unless @results.posts.present?

    @results
  end

  private

    def process_advanced_search!(term)

      term.to_s.split(/\s+/).map do |word|
        if word == 'status:open'
          @status = :open
          nil
        elsif word == 'status:closed'
          @status = :closed
          nil
        elsif word == 'status:archived'
          @status = :archived
          nil
        elsif word == 'status:noreplies'
          @posts_count = 1
          nil
        elsif word == 'status:singleuser'
          @single_user = true
          nil
        elsif word == 'order:latest'
          @order = :latest
          nil
        elsif word == 'order:views'
          @order = :views
          nil
        elsif word =~ /category:(.+)/
          @category_id = Category.find_by('name ilike ?', $1).try(:id)
          nil
        elsif word =~ /user:(.+)/
          @user_id = User.find_by('username_lower = ?', $1.downcase).try(:id)
          nil
        elsif word == 'in:likes'
          @liked_only = true
          nil
        elsif word == 'in:posted'
          @posted_only = true
          nil
        elsif word == 'in:watching'
          @notification_level = TopicUser.notification_levels[:watching]
          nil
        elsif word == 'in:tracking'
          @notification_level = TopicUser.notification_levels[:tracking]
          nil
        else
          word
        end
      end.compact.join(' ')
    end


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
      expected_topics -= @results.posts.length
      if expected_topics > 0
        extra_posts = posts_query(expected_topics * Search.burst_factor)
        extra_posts = extra_posts.where("posts.topic_id NOT in (?)", @results.posts.map(&:topic_id)) if @results.posts.present?
        extra_posts.each do |post|
          @results.add(post)
          expected_topics -= 1
          break if expected_topics == 0
        end
      end
    end

    # If we're searching for a single topic
    def single_topic(id)
      post = Post.find_by(topic_id: id, post_number: 1)
      return nil unless @guardian.can_see?(post)

      @results.add(post)
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

      categories.each do |category|
        @results.add(category)
      end
    end

    def user_search
      users = User.includes(:user_search_data)
                  .where("active = true AND user_search_data.search_data @@ #{ts_query("simple")}")
                  .order("CASE WHEN username_lower = '#{@original_term.downcase}' THEN 0 ELSE 1 END")
                  .order("last_posted_at DESC")
                  .limit(@limit)
                  .references(:user_search_data)

      users.each do |user|
        @results.add(user)
      end
    end

    def posts_query(limit, opts=nil)
      opts ||= {}
      posts = Post
                  .joins(:post_search_data, {:topic => :category})
                  .where("topics.deleted_at" => nil)
                  .where("topics.visible")
                  .where("topics.archetype <> ?", Archetype.private_message)

      if @search_context.present? && @search_context.is_a?(Topic)
        posts = posts.joins('JOIN users u ON u.id = posts.user_id')
        posts = posts.where("posts.raw  || ' ' || u.username || ' ' || u.name ilike ?", "%#{@term}%")
      else
        posts = posts.where("post_search_data.search_data @@ #{ts_query}")
      end

      if @status == :open
        posts = posts.where('NOT topics.closed AND NOT topics.archived')
      elsif @status == :archived
        posts = posts.where('topics.archived')
      elsif @status == :closed
        posts = posts.where('topics.closed')
      end

      if @single_user
        posts = posts.where("topics.featured_user1_id IS NULL AND topics.last_post_user_id = topics.user_id")
      end

      if @posts_count
        posts = posts.where("topics.posts_count = #{@posts_count}")
      end

      if @user_id
        posts = posts.where("posts.user_id = #{@user_id}")
      end

      if @guardian.user
        if @liked_only
          posts = posts.where("posts.id IN (
                                SELECT pa.post_id FROM post_actions pa
                                WHERE pa.user_id = #{@guardian.user.id} AND
                                      pa.post_action_type_id = #{PostActionType.types[:like]}
                             )")
        end

        if @posted_only
          posts = posts.where("posts.user_id = #{@guardian.user.id}")
        end

        if @notification_level
          posts = posts.where("posts.topic_id IN (
                              SELECT tu.topic_id FROM topic_users tu
                              WHERE tu.user_id = #{@guardian.user.id} AND
                                    tu.notification_level >= #{@notification_level}
                             )")
        end

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

      if @category_id
        posts = posts.where("topics.category_id = ?", @category_id)
      end

      if @order == :latest
        if opts[:aggregate_search]
          posts = posts.order("MAX(posts.created_at) DESC")
        else
          posts = posts.order("posts.created_at DESC")
        end
      elsif @order == :views
        if opts[:aggregate_search]
          posts = posts.order("MAX(topics.views) DESC")
        else
          posts = posts.order("topics.views DESC")
        end
      else
        posts = posts.order("TS_RANK_CD(TO_TSVECTOR(#{query_locale}, topics.title), #{ts_query}) DESC")

        data_ranking = "TS_RANK_CD(post_search_data.search_data, #{ts_query})"
        if opts[:aggregate_search]
          posts = posts.order("SUM(#{data_ranking}) DESC")
        else
          posts = posts.order("#{data_ranking} DESC")
        end
        posts = posts.order("topics.bumped_at DESC")
      end

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

    def self.ts_query(term, locale = nil, joiner = "&")
      locale = Post.sanitize(locale) if locale
      all_terms = term.gsub(/[*:()&!'"]/,'').squish.split
      query = Post.sanitize(all_terms.map {|t| "#{PG::Connection.escape_string(t)}:*"}.join(" #{joiner} "))
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

    def aggregate_search

      post_sql = posts_query(@limit, aggregate_search: true)
        .select('topics.id', 'min(post_number) post_number')
        .group('topics.id')
        .to_sql

      # double wrapping so we get correct row numbers
      post_sql = "SELECT *, row_number() over() row_number FROM (#{post_sql}) xxx"

      posts = Post.includes(:topic => :category)
                  .joins("JOIN (#{post_sql}) x ON x.id = posts.topic_id AND x.post_number = posts.post_number")
                  .order('row_number')

      posts.each do |post|
        @results.add(post)
      end
    end

    def topic_search
      if @search_context.is_a?(Topic)
        posts = posts_query(@limit).where('posts.topic_id = ?', @search_context.id).includes(:topic => :category)
        posts.each do |post|
          @results.add(post)
        end
      else
        aggregate_search
      end
    end

end
