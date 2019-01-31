require_dependency 'search/grouped_search_results'

class Search
  INDEX_VERSION = 2.freeze
  DIACRITICS ||= /([\u0300-\u036f]|[\u1AB0-\u1AFF]|[\u1DC0-\u1DFF]|[\u20D0-\u20FF])/

  def self.per_facet
    5
  end

  def self.strip_diacritics(str)
    s = str.unicode_normalize(:nfkd)
    s.gsub!(DIACRITICS, "")
    s.strip!
    s
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
    %w(topic category user private_messages tags)
  end

  def self.ts_config(locale = SiteSetting.default_locale)
    # if adding a text search configuration, you should check PG beforehand:
    # SELECT cfgname FROM pg_ts_config;
    # As an aside, dictionaries can be listed by `\dFd`, the
    # physical locations are in /usr/share/postgresql/<version>/tsearch_data.
    # But it may not appear there based on pg extension configuration.
    # base docker config
    #
    case locale.to_sym
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

  def self.prepare_data(search_data, purpose = :query)
    purpose ||= :query

    data = search_data.dup
    data.force_encoding("UTF-8")
    if purpose != :topic
      # TODO cppjieba_rb is designed for chinese, we need something else for Japanese
      # Korean appears to be safe cause words are already space seperated
      # For Japanese we should investigate using kakasi
      if ['zh_TW', 'zh_CN', 'ja'].include?(SiteSetting.default_locale) || SiteSetting.search_tokenize_chinese_japanese_korean
        require 'cppjieba_rb' unless defined? CppjiebaRb
        mode = (purpose == :query ? :query : :mix)
        data = CppjiebaRb.segment(search_data, mode: mode)
        data = CppjiebaRb.filter_stop_word(data).join(' ')
      else
        data.squish!
      end

      if SiteSetting.search_ignore_accents
        data = strip_diacritics(data)
      end
    end
    data
  end

  def self.word_to_date(str)

    if str =~ /^[0-9]{1,3}$/
      return Time.zone.now.beginning_of_day.days_ago(str.to_i)
    end

    if str =~ /^([12][0-9]{3})(-([0-1]?[0-9]))?(-([0-3]?[0-9]))?$/
      year = $1.to_i
      month = $2 ? $3.to_i : 1
      day = $4 ? $5.to_i : 1

      return if day == 0 || month == 0 || day > 31 || month > 12

      return begin
        Time.zone.parse("#{year}-#{month}-#{day}")
      rescue ArgumentError
      end
    end

    if str.downcase == "yesterday"
      return Time.zone.now.beginning_of_day.yesterday
    end

    titlecase = str.downcase.titlecase

    if Date::DAYNAMES.include?(titlecase)
      return Time.zone.now.beginning_of_week(str.downcase.to_sym)
    end

    if idx = (Date::MONTHNAMES.find_index(titlecase) ||
              Date::ABBR_MONTHNAMES.find_index(titlecase))
      delta = Time.zone.now.month - idx
      delta += 12 if delta < 0
      Time.zone.now.beginning_of_month.months_ago(delta)
    end
  end

  def self.min_post_id_no_cache
    return 0 unless SiteSetting.search_prefer_recent_posts?

    offset, has_more = Post.unscoped
      .order('id desc')
      .offset(SiteSetting.search_recent_posts_size - 1)
      .limit(2)
      .pluck(:id)

    has_more ? offset : 0
  end

  def self.min_post_id(opts = nil)
    return 0 unless SiteSetting.search_prefer_recent_posts?

    # It can be quite slow to count all the posts so let's cache it
    Rails.cache.fetch("search-min-post-id:#{SiteSetting.search_recent_posts_size}", expires_in: 1.week) do
      min_post_id_no_cache
    end
  end

  attr_accessor :term
  attr_reader :clean_term

  def initialize(term, opts = nil)
    @opts = opts || {}
    @guardian = @opts[:guardian] || Guardian.new
    @search_context = @opts[:search_context]
    @include_blurbs = @opts[:include_blurbs] || false
    @blurb_length = @opts[:blurb_length]
    @valid = true
    @page = @opts[:page]

    term = term.to_s.dup

    # Removes any zero-width characters from search terms
    term.gsub!(/[\u200B-\u200D\uFEFF]/, '')
    # Replace curly quotes to regular quotes
    term.gsub!(/[\u201c\u201d]/, '"')

    @clean_term = term

    term = process_advanced_search!(term)

    if term.present?
      @term = Search.prepare_data(term, Topic === @search_context ? :topic : nil)
      @original_term = PG::Connection.escape_string(@term)
    end

    if @search_pms && @guardian.user
      @opts[:type_filter] = "private_messages"
      @search_context = @guardian.user
    end

    @results = GroupedSearchResults.new(
      @opts[:type_filter],
      clean_term,
      @search_context,
      @include_blurbs,
      @blurb_length
    )
  end

  def limit
    if @opts[:type_filter].present?
      Search.per_filter + 1
    else
      Search.per_facet + 1
    end
  end

  def offset
    if @page && @opts[:type_filter].present?
      (@page - 1) * Search.per_filter
    else
      0
    end
  end

  def valid?
    @valid
  end

  def self.execute(term, opts = nil)
    self.new(term, opts).execute
  end

  # Query a term
  def execute
    if SiteSetting.log_search_queries? && @opts[:search_type].present?
      status, search_log_id = SearchLog.log(
        term: @term,
        search_type: @opts[:search_type],
        ip_address: @opts[:ip_address],
        user_id: @opts[:user_id]
      )
      @results.search_log_id = search_log_id unless status == :error
    end

    unless @filters.present? || @opts[:search_for_id]
      min_length = @opts[:min_search_term_length] || SiteSetting.min_search_term_length
      terms = (@term || '').split(/\s(?=(?:[^"]|"[^"]*")*$)/).reject { |t| t.length < min_length }

      if terms.blank?
        @term = ''
        @valid = false
        return
      end
    end

    # If the term is a number or url to a topic, just include that topic
    if @opts[:search_for_id] && (@results.type_filter == 'topic' || @results.type_filter == 'private_messages')
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

  def self.advanced_filter(trigger, &block)
    (@advanced_filters ||= {})[trigger] = block
  end

  def self.advanced_filters
    @advanced_filters
  end

  advanced_filter(/status:open/) do |posts|
    posts.where('NOT topics.closed AND NOT topics.archived')
  end

  advanced_filter(/status:closed/) do |posts|
    posts.where('topics.closed')
  end

  advanced_filter(/status:archived/) do |posts|
    posts.where('topics.archived')
  end

  advanced_filter(/status:noreplies/) do |posts|
    posts.where("topics.posts_count = 1")
  end

  advanced_filter(/status:single_user/) do |posts|
    posts.where("topics.participant_count = 1")
  end

  advanced_filter(/posts_count:(\d+)/) do |posts, match|
    posts.where("topics.posts_count = ?", match.to_i)
  end

  advanced_filter(/min_post_count:(\d+)/) do |posts, match|
    posts.where("topics.posts_count >= ?", match.to_i)
  end

  advanced_filter(/in:first/) do |posts|
    posts.where("posts.post_number = 1")
  end

  advanced_filter(/in:pinned/) do |posts|
    posts.where("topics.pinned_at IS NOT NULL")
  end

  advanced_filter(/in:unpinned/) do |posts|
    if @guardian.user
      posts.where("topics.pinned_at IS NOT NULL AND topics.id IN (
                  SELECT topic_id FROM topic_users WHERE user_id = ? AND cleared_pinned_at IS NOT NULL
                 )", @guardian.user.id)
    end
  end

  advanced_filter(/in:wiki/) do |posts, match|
    posts.where(wiki: true)
  end

  advanced_filter(/badge:(.*)/) do |posts, match|
    badge_id = Badge.where('name ilike ? OR id = ?', match, match.to_i).pluck(:id).first
    if badge_id
      posts.where('posts.user_id IN (SELECT ub.user_id FROM user_badges ub WHERE ub.badge_id = ?)', badge_id)
    else
      posts.where("1 = 0")
    end
  end

  advanced_filter(/in:(likes|bookmarks)/) do |posts, match|
    if @guardian.user
      post_action_type = PostActionType.types[:like] if match == "likes"
      post_action_type = PostActionType.types[:bookmark] if match == "bookmarks"

      posts.where("posts.id IN (
                            SELECT pa.post_id FROM post_actions pa
                            WHERE pa.user_id = #{@guardian.user.id} AND
                                  pa.post_action_type_id = #{post_action_type} AND
                                  deleted_at IS NULL
                         )")
    end
  end

  advanced_filter(/in:posted/) do |posts|
    posts.where("posts.user_id = #{@guardian.user.id}") if @guardian.user
  end

  advanced_filter(/in:(watching|tracking)/) do |posts, match|
    if @guardian.user
      level = TopicUser.notification_levels[match.to_sym]
      posts.where("posts.topic_id IN (
                    SELECT tu.topic_id FROM topic_users tu
                    WHERE tu.user_id = :user_id AND
                          tu.notification_level >= :level
                   )", user_id: @guardian.user.id, level: level)

    end
  end

  advanced_filter(/in:seen/) do |posts|
    if @guardian.user
      posts
        .joins("INNER JOIN post_timings ON
          post_timings.topic_id = posts.topic_id
          AND post_timings.post_number = posts.post_number
          AND post_timings.user_id = #{ActiveRecord::Base.connection.quote(@guardian.user.id)}
        ")
    end
  end

  advanced_filter(/in:unseen/) do |posts|
    if @guardian.user
      posts
        .joins("LEFT JOIN post_timings ON
          post_timings.topic_id = posts.topic_id
          AND post_timings.post_number = posts.post_number
          AND post_timings.user_id = #{ActiveRecord::Base.connection.quote(@guardian.user.id)}
        ")
        .where("post_timings.user_id IS NULL")
    end
  end

  advanced_filter(/with:images/) do |posts|
    posts.where("posts.image_url IS NOT NULL")
  end

  advanced_filter(/category:(.+)/) do |posts, match|
    exact = false

    if match[0] == "="
      exact = true
      match = match[1..-1]
    end

    category_ids = Category.where('slug ilike ? OR name ilike ? OR id = ?',
                                  match, match, match.to_i).pluck(:id)
    if category_ids.present?

      unless exact
        category_ids +=
          Category.where('parent_category_id = ?', category_ids.first).pluck(:id)
      end

      posts.where("topics.category_id IN (?)", category_ids)
    else
      posts.where("1 = 0")
    end
  end

  advanced_filter(/^\#([\p{L}0-9\-:=]+)/) do |posts, match|

    exact = true

    slug = match.to_s.split(":")
    next if slug.empty?

    if slug[1]
      # sub category
      parent_category_id = Category.where(slug: slug[0].downcase, parent_category_id: nil).pluck(:id).first
      category_id = Category.where(slug: slug[1].downcase, parent_category_id: parent_category_id).pluck(:id).first
    else
      # main category
      if slug[0][0] == "="
        slug[0] = slug[0][1..-1]
      else
        exact = false
      end

      category_id = Category.where(slug: slug[0].downcase)
        .order('case when parent_category_id is null then 0 else 1 end')
        .pluck(:id)
        .first
    end

    if category_id
      category_ids = [category_id]

      unless exact
        category_ids +=
          Category.where('parent_category_id = ?', category_id).pluck(:id)
      end
      posts.where("topics.category_id IN (?)", category_ids)
    else
      # try a possible tag match
      tag_id = Tag.where_name(slug[0]).pluck(:id).first
      if (tag_id)
        posts.where("topics.id IN (
          SELECT DISTINCT(tt.topic_id)
          FROM topic_tags tt
          WHERE tt.tag_id = ?
          )", tag_id)
      else
        # a bit yucky but we got to add the term back in
        if match.to_s.length >= SiteSetting.min_search_term_length
          posts.where("posts.id IN (
            SELECT post_id FROM post_search_data pd1
            WHERE pd1.search_data @@ #{Search.ts_query(term: "##{match}")})")
        end
      end
    end
  end

  advanced_filter(/group:(.+)/) do |posts, match|
    group_id = Group.where('name ilike ? OR (id = ? AND id > 0)', match, match.to_i).pluck(:id).first
    if group_id
      posts.where("posts.user_id IN (select gu.user_id from group_users gu where gu.group_id = ?)", group_id)
    else
      posts.where("1 = 0")
    end
  end

  advanced_filter(/user:(.+)/) do |posts, match|
    user_id = User.where(staged: false).where('username_lower = ? OR id = ?', match.downcase, match.to_i).pluck(:id).first
    if user_id
      posts.where("posts.user_id = #{user_id}")
    else
      posts.where("1 = 0")
    end
  end

  advanced_filter(/^\@([a-zA-Z0-9_\-.]+)/) do |posts, match|
    user_id = User.where(staged: false).where(username_lower: match.downcase).pluck(:id).first
    if user_id
      posts.where("posts.user_id = #{user_id}")
    else
      posts.where("1 = 0")
    end
  end

  advanced_filter(/before:(.*)/) do |posts, match|
    if date = Search.word_to_date(match)
      posts.where("posts.created_at < ?", date)
    else
      posts
    end
  end

  advanced_filter(/after:(.*)/) do |posts, match|
    if date = Search.word_to_date(match)
      posts.where("posts.created_at > ?", date)
    else
      posts
    end
  end

  advanced_filter(/^tags?:([\p{L}0-9,\-_+]+)/) do |posts, match|
    search_tags(posts, match, positive: true)
  end

  advanced_filter(/\-tags?:([\p{L}0-9,\-_+]+)/) do |posts, match|
    search_tags(posts, match, positive: false)
  end

  advanced_filter(/filetypes?:([a-zA-Z0-9,\-_]+)/) do |posts, match|
    file_extensions = match.split(",").map(&:downcase)
    posts.where("posts.id IN (
      SELECT post_id
        FROM topic_links
       WHERE extension IN (:file_extensions)

      UNION

      SELECT post_uploads.post_id
        FROM uploads
        JOIN post_uploads ON post_uploads.upload_id = uploads.id
       WHERE lower(uploads.extension) IN (:file_extensions)
    )", file_extensions: file_extensions)
  end

  private

  def search_tags(posts, match, positive:)
    return if match.nil?
    match.downcase!
    modifier = positive ? "" : "NOT"

    if match.include?('+')
      tags = match.split('+')

      posts.where("topics.id #{modifier} IN (
        SELECT tt.topic_id
        FROM topic_tags tt, tags
        WHERE tt.tag_id = tags.id
        GROUP BY tt.topic_id
        HAVING to_tsvector(#{default_ts_config}, array_to_string(array_agg(lower(tags.name)), ' ')) @@ to_tsquery(#{default_ts_config}, ?)
      )", tags.join('&'))
    else
      tags = match.split(",")

      posts.where("topics.id #{modifier} IN (
        SELECT DISTINCT(tt.topic_id)
        FROM topic_tags tt, tags
        WHERE tt.tag_id = tags.id AND lower(tags.name) IN (?)
      )", tags)
    end
  end

  def process_advanced_search!(term)
    term.to_s.scan(/(([^" \t\n\x0B\f\r]+)?(("[^"]+")?))/).to_a.map do |(word, _)|
      next if word.blank?

      found = false

      Search.advanced_filters.each do |matcher, block|
        cleaned = word.gsub(/["']/, "")
        if cleaned =~ matcher
          (@filters ||= []) << [block, $1]
          found = true
        end
      end

      @in_title = false

      if word == 'order:latest' || word == 'l'
        @order = :latest
        nil
      elsif word == 'order:latest_topic'
        @order = :latest_topic
        nil
      elsif word == 'in:title'
        @in_title = true
        nil
      elsif word =~ /topic:(\d+)/
        topic_id = $1.to_i
        if topic_id > 1
          topic = Topic.find_by(id: topic_id)
          if @guardian.can_see?(topic)
            @search_context = topic
          end
        end
        nil
      elsif word == 'order:views'
        @order = :views
        nil
      elsif word == 'order:likes'
        @order = :likes
        nil
      elsif word == 'in:private'
        @search_pms = true
        nil
      elsif word =~ /^private_messages:(.+)$/
        @search_pms = true
        nil
      else
        found ? nil : word
      end
    end.compact.join(' ')
  end

  def find_grouped_results

    if @results.type_filter.present?
      raise Discourse::InvalidAccess.new("invalid type filter") unless Search.facets.include?(@results.type_filter)
      send("#{@results.type_filter}_search")
    else
      unless @search_context
        user_search if @term.present?
        category_search if @term.present?
        tags_search if @term.present?
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
    if @opts[:restrict_to_archetype].present?
      archetype = @opts[:restrict_to_archetype] == Archetype.default ? Archetype.default : Archetype.private_message
      post = Post.joins(:topic)
        .where("topics.id = :id AND topics.archetype = :archetype AND posts.post_number = 1", id: id, archetype: archetype)
        .first
    else
      post = Post.find_by(topic_id: id, post_number: 1)
    end
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
      .limit(limit)

    categories.each do |category|
      @results.add(category)
    end
  end

  def user_search
    return if SiteSetting.hide_user_profiles_from_public && !@guardian.user

    users = User.includes(:user_search_data)
      .references(:user_search_data)
      .where(active: true)
      .where(staged: false)
      .where("user_search_data.search_data @@ #{ts_query("simple")}")
      .order("CASE WHEN username_lower = '#{@original_term.downcase}' THEN 0 ELSE 1 END")
      .order("last_posted_at DESC")
      .limit(limit)

    users.each do |user|
      @results.add(user)
    end
  end

  def tags_search
    return unless SiteSetting.tagging_enabled

    tags = Tag.includes(:tag_search_data)
      .where("tag_search_data.search_data @@ #{ts_query}")
      .references(:tag_search_data)
      .order("name asc")
      .limit(limit)

    tags.each do |tag|
      @results.add(tag)
    end
  end

  def posts_query(limit, opts = nil)
    opts ||= {}
    posts = Post.where(post_type: Topic.visible_post_types(@guardian.user))
      .joins(:post_search_data, :topic)
      .joins("LEFT JOIN categories ON categories.id = topics.category_id")
      .where("topics.deleted_at" => nil)

    is_topic_search = @search_context.present? && @search_context.is_a?(Topic)

    posts = posts.where("topics.visible") unless is_topic_search

    if opts[:private_messages] || (is_topic_search && @search_context.private_message?)
      posts = posts.where("topics.archetype =  ?", Archetype.private_message)

       unless @guardian.is_admin?
         posts = posts.private_posts_for_user(@guardian.user)
       end
    else
      posts = posts.where("topics.archetype <> ?", Archetype.private_message)
    end

    if @term.present?
      if is_topic_search

        term_without_quote = @term
        if @term =~ /"(.+)"/
          term_without_quote = $1
        end

        if @term =~ /'(.+)'/
          term_without_quote = $1
        end

        posts = posts.joins('JOIN users u ON u.id = posts.user_id')
        posts = posts.where("posts.raw  || ' ' || u.username || ' ' || COALESCE(u.name, '') ilike ?", "%#{term_without_quote}%")
      else
        # A is for title
        # B is for category
        # C is for tags
        # D is for cooked
        weights = @in_title ? 'A' : (SiteSetting.tagging_enabled ? 'ABCD' : 'ABD')
        posts = posts.where("post_search_data.search_data @@ #{ts_query(weight_filter: weights)}")
        exact_terms = @term.scan(/"([^"]+)"/).flatten
        exact_terms.each do |exact|
          posts = posts.where("posts.raw ilike :exact OR topics.title ilike :exact", exact: "%#{exact}%")
        end
      end
    end

    @filters.each do |block, match|
      if block.arity == 1
        posts = instance_exec(posts, &block) || posts
      else
        posts = instance_exec(posts, match, &block) || posts
      end
    end if @filters

    # If we have a search context, prioritize those posts first
    if @search_context.present?

      if @search_context.is_a?(User)

        if opts[:private_messages]
          posts = posts.private_posts_for_user(@search_context)
        else
          posts = posts.where("posts.user_id = #{@search_context.id}")
        end

      elsif @search_context.is_a?(Category)
        category_ids = [@search_context.id] + Category.where(parent_category_id: @search_context.id).pluck(:id)
        posts = posts.where("topics.category_id in (?)", category_ids)
      elsif @search_context.is_a?(Topic)
        posts = posts.where("topics.id = #{@search_context.id}")
          .order("posts.post_number #{@order == :latest ? "DESC" : ""}")
      end

    end

    if @order == :latest || (@term.blank? && !@order)
      if opts[:aggregate_search]
        posts = posts.order("MAX(posts.created_at) DESC")
      else
        posts = posts.reorder("posts.created_at DESC")
      end
    elsif @order == :latest_topic
      if opts[:aggregate_search]
        posts = posts.order("MAX(topics.created_at) DESC")
      else
        posts = posts.order("topics.created_at DESC")
      end
    elsif @order == :views
      if opts[:aggregate_search]
        posts = posts.order("MAX(topics.views) DESC")
      else
        posts = posts.order("topics.views DESC")
      end
    elsif @order == :likes
      if opts[:aggregate_search]
        posts = posts.order("MAX(posts.like_count) DESC")
      else
        posts = posts.order("posts.like_count DESC")
      end
    else
      data_ranking = "TS_RANK_CD(post_search_data.search_data, #{ts_query})"
      if opts[:aggregate_search]
        posts = posts.order("MAX(#{data_ranking}) DESC")
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

    posts = posts.offset(offset)
    posts.limit(limit)
  end

  def self.default_ts_config
    "'#{Search.ts_config}'"
  end

  def default_ts_config
    self.class.default_ts_config
  end

  def self.ts_query(term: , ts_config:  nil, joiner: "&", weight_filter: nil)

    data = DB.query_single(
      "SELECT TO_TSVECTOR(:config, :term)",
      config: 'simple',
      term: term
    ).first

    ts_config = ActiveRecord::Base.connection.quote(ts_config) if ts_config
    all_terms = data.scan(/'([^']+)'\:\d+/).flatten
    all_terms.map! do |t|
      t.split(/[\)\(&']/).find(&:present?)
    end.compact!

    query = ActiveRecord::Base.connection.quote(
      all_terms
        .map { |t| "'#{PG::Connection.escape_string(t)}':*#{weight_filter}" }
        .join(" #{joiner} ")
    )

    "TO_TSQUERY(#{ts_config || default_ts_config}, #{query})"
  end

  def ts_query(ts_config = nil, weight_filter: nil)
    @ts_query_cache ||= {}
    @ts_query_cache["#{ts_config || default_ts_config} #{@term} #{weight_filter}"] ||=
      Search.ts_query(term: @term, ts_config: ts_config, weight_filter: weight_filter)
  end

  def wrap_rows(query)
    "SELECT *, row_number() over() row_number FROM (#{query.to_sql}) xxx"
  end

  def aggregate_post_sql(opts)
    min_or_max = @order == :latest ? "max" : "min"

    query =
      if @order == :likes
        # likes are a pain to aggregate so skip
        posts_query(limit, private_messages: opts[:private_messages])
          .select('topics.id', "posts.post_number")
      else
        posts_query(limit, aggregate_search: true, private_messages: opts[:private_messages])
          .select('topics.id', "#{min_or_max}(posts.post_number) post_number")
          .group('topics.id')
      end

    min_id = Search.min_post_id
    if min_id > 0
      low_set = query.dup.where("post_search_data.post_id < #{min_id}")
      high_set = query.where("post_search_data.post_id >= #{min_id}")

      return { default: wrap_rows(high_set), remaining: wrap_rows(low_set) }
    end

    # double wrapping so we get correct row numbers
    { default: wrap_rows(query) }
  end

  def aggregate_posts(post_sql)
    return [] unless post_sql

    posts_eager_loads(Post)
      .joins("JOIN (#{post_sql}) x ON x.id = posts.topic_id AND x.post_number = posts.post_number")
      .order('row_number')
  end

  def aggregate_search(opts = {})
    post_sql = aggregate_post_sql(opts)

    added = 0

    aggregate_posts(post_sql[:default]).each do |p|
      @results.add(p)
      added += 1
    end

    if added < limit
      aggregate_posts(post_sql[:remaining]).each { |p| @results.add(p) }
    end
  end

  def private_messages_search
    raise Discourse::InvalidAccess.new("anonymous can not search PMs") unless @guardian.user

    aggregate_search(private_messages: true)
  end

  def topic_search
    if @search_context.is_a?(Topic)
      posts = posts_eager_loads(posts_query(limit))
        .where('posts.topic_id = ?', @search_context.id)

      posts.each do |post|
        @results.add(post)
      end
    else
      aggregate_search
    end
  end

  def posts_eager_loads(query)
    query = query.includes(:user)
    topic_eager_loads = [:category]

    if SiteSetting.tagging_enabled
      topic_eager_loads << :tags
    end

    query.includes(topic: topic_eager_loads)
  end

end
