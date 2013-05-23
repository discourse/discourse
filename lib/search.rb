class Search

  def self.per_facet
    5
  end

  def self.facets
    %w(topic category user)
  end

  def self.current_locale_long
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
      else 'simple' # use the 'simple' stemmer for other languages
    end
  end

  def initialize(term, opts=nil)
    @term = term.to_s if term.present?
    @opts = opts || {}
    @guardian = @opts[:guardian] || Guardian.new
  end

  # Query a term
  def execute

    return nil if @term.blank?

    # really short terms are totally pointless
    return nil if @term.length < (@opts[:min_search_term_length] || SiteSetting.min_search_term_length)

    # If the term is a number or url to a topic, just include that topic
    if @opts[:type_filter] == 'topic'

      begin
        route = Rails.application.routes.recognize_path(@term)
        return single_topic(route[:topic_id]) if route[:topic_id].present?
      rescue ActionController::RoutingError
      end

      return single_topic(@term.to_i) if @term =~ /^\d+$/
    end

    # We are stripping only symbols taking place in FTS and simply sanitizing the rest.
    @term = PG::Connection.escape_string(@term.gsub(/[:()&!]/,''))

    query_string
  end

  private

    # Search for a string term
    def query_string

      args = {orig: @term,
              query: @term.split.map {|t| "#{t}:*"}.join(" & "),
              locale: Search.current_locale_long}

      results = GroupedSearchResults.new(@opts[:type_filter])
      type_filter = @opts[:type_filter]

      if type_filter.present?
        raise Discourse::InvalidAccess.new("invalid type filter") unless Search.facets.include?(type_filter)
        args.merge!(limit: Search.per_facet * Search.facets.size)
        case type_filter.to_s
        when 'topic'
          results.add(post_query(type_filter.to_sym, args))
        when 'category'
          results.add(category_query(args))
        when 'user'
          results.add(user_query(args))
        end
      else
        args.merge!(limit: (Search.per_facet + 1))
        results.add(user_query(args).to_a)
        results.add(category_query(args).to_a)
        results.add(post_query(:topic, args).to_a)
      end

      expected_topics = 0
      expected_topics = Search.facets.size unless type_filter.present?
      expected_topics = Search.per_facet * Search.facets.size if type_filter == 'topic'


      # Subtract how many topics we have
      expected_topics -= results.topic_count

       if expected_topics > 0
        extra_topics = post_query(:post, args.merge(limit: expected_topics * 3)).to_a

        topic_ids = results.topic_ids
        extra_topics.reject! do |i|
          new_topic_id = i['id'].to_i
          if topic_ids.include?(new_topic_id)
            true
          else
            topic_ids << new_topic_id
            false
          end
        end
        results.add(extra_topics[0..expected_topics-1])
      end

      results.as_json
    end


    # If we're searching for a single topic
    def single_topic(id)
      topic = Topic.where(id: id).first
      return nil unless @guardian.can_see?(topic)

      results = GroupedSearchResults.new(@opts[:type_filter])
      results.add('type' => 'topic',
                  'id' => topic.id,
                  'url' => topic.relative_url,
                  'title' => topic.title)
      results.as_json
    end

    def add_allowed_categories(builder)
      allowed_categories = nil
      allowed_categories = @guardian.secure_category_ids
      if allowed_categories.present?
        builder.where("(c.id IS NULL OR c.secure OR c.id in (:category_ids))", category_ids: allowed_categories)
      else
        builder.where("(c.id IS NULL OR (NOT c.secure))")
      end
    end


    def category_query(args)
      builder = SqlBuilder.new <<SQL
    SELECT 'category' AS type,
            c.name AS id,
            '/category/' || c.slug AS url,
            c.name AS title,
            NULL AS email,
            c.color,
            c.text_color
    FROM categories AS c
    JOIN category_search_data s on s.category_id = c.id
    /*where*/
    ORDER BY topics_month desc
    LIMIT :limit
SQL

      builder.where "s.search_data @@ TO_TSQUERY(:locale, :query)"
      add_allowed_categories(builder)

      builder.exec(args)
    end

    def user_query(args)
      sql = "SELECT 'user' AS type,
                    u.username_lower AS id,
                    '/users/' || u.username_lower AS url,
                    u.username AS title,
                    u.email
            FROM users AS u
            JOIN user_search_data s on s.user_id = u.id
            WHERE s.search_data @@ TO_TSQUERY(:locale, :query)
            ORDER BY CASE WHEN u.username_lower = lower(:orig) then 0 else 1 end,  last_posted_at desc
            LIMIT :limit"
      ActiveRecord::Base.exec_sql(sql, args)
    end

    def post_query(type, args)
      builder = SqlBuilder.new <<SQL
      /*select*/
      FROM topics AS ft
      /*join*/
        JOIN post_search_data s on s.post_id = p.id
        LEFT JOIN categories c ON c.id = ft.category_id
      /*where*/
      ORDER BY
              TS_RANK_CD(TO_TSVECTOR(:locale, ft.title), TO_TSQUERY(:locale, :query)) desc,
              TS_RANK_CD(search_data, TO_TSQUERY(:locale, :query)) desc,
              bumped_at desc
      LIMIT :limit
SQL

      builder.select "'topic' AS type"
      builder.select("CAST(ft.id AS VARCHAR)")

      if type == :topic
        builder.select "'/t/slug/' || ft.id AS url"
      else
        builder.select "'/t/slug/' || ft.id || '/' || p.post_number AS url"
      end

      builder.select "ft.title, NULL AS email, NULL AS color, NULL AS text_color"

      if type == :topic
        builder.join "posts AS p ON p.topic_id = ft.id AND p.post_number = 1"
      else
        builder.join "posts AS p ON p.topic_id = ft.id AND p.post_number > 1"
      end

      builder.where <<SQL
  s.search_data @@ TO_TSQUERY(:locale, :query)
        AND ft.deleted_at IS NULL
        AND p.deleted_at IS NULL
        AND ft.visible
        AND ft.archetype <> '#{Archetype.private_message}'
SQL

      add_allowed_categories(builder)

      builder.exec(args)
    end

    class SearchResult
      attr_accessor :type, :id

      def initialize(row)
        @type = row['type'].to_sym
        @url, @id, @title = row['url'], row['id'].to_i, row['title']

        case @type
        when :topic
          # Some topics don't have slugs. In that case, use 'topic' as the slug.
          new_slug = Slug.for(row['title'])
          new_slug = "topic" if new_slug.blank?
          @url.gsub!('slug', new_slug)
        when :user
          @avatar_template = User.avatar_template(row['email'])
        when :category
          @color, @text_color = row['color'], row['text_color']
        end
      end

      def as_json
        json = {id: @id, title: @title, url: @url}
        json[:avatar_template] = @avatar_template if @avatar_template.present?
        json[:color] = @color if @color.present?
        json[:text_color] = @text_color if @text_color.present?
        json
      end
    end

    class SearchResultType

      attr_accessor :more, :results

      def initialize(type)
        @type = type
        @results = []
        @more = false
      end

      def size
        @results.size
      end

      def add(result)
        @results << result
      end

      def as_json
        { type: @type.to_s,
          name: I18n.t("search.types.#{@type.to_s}"),
          more: @more,
          results: @results.map(&:as_json) }
      end
    end

    class GroupedSearchResults

      attr_reader :topic_count

      def initialize(type_filter)
        @type_filter = type_filter
        @by_type = {}
        @topic_count = 0
      end

      def add(results)
        results = [results] if results.is_a?(Hash)

        results.each do |r|
          add_result(SearchResult.new(r))
        end
      end

      def add_result(result)
        grouped_result = @by_type[result.type] || (@by_type[result.type] = SearchResultType.new(result.type))

        # Limit our results if there is no filter
        if @type_filter.present? or (grouped_result.size < Search.per_facet)
          @topic_count += 1 if (result.type == :topic)

          grouped_result.add(result)
        else
          grouped_result.more = true
        end
      end

      def topic_ids
        topic_results = @by_type[:topic]
        return Set.new if topic_results.blank?

        Set.new(topic_results.results.map(&:id))
      end

      def as_json
        @by_type.values.map do |grouped_result|
          grouped_result.as_json
        end
      end

    end

end
