# frozen_string_literal: true

class Search
  DIACRITICS = /([\u0300-\u036f]|[\u1AB0-\u1AFF]|[\u1DC0-\u1DFF]|[\u20D0-\u20FF])/
  HIGHLIGHT_CSS_CLASS = "search-highlight"

  cattr_accessor :preloaded_topic_custom_fields
  self.preloaded_topic_custom_fields = Set.new

  def self.on_preload(&blk)
    (@preload ||= Set.new) << blk
  end

  def self.preload(results, object)
    @preload.each { |preload| preload.call(results, object) } if @preload
  end

  def self.per_facet
    5
  end

  def self.per_filter
    SiteSetting.search_page_size
  end

  def self.facets
    %w[topic category user private_messages tags all_topics exclude_topics]
  end

  def self.ts_config(locale = SiteSetting.default_locale)
    # if adding a text search configuration, you should check PG beforehand:
    # SELECT cfgname FROM pg_ts_config;
    # As an aside, dictionaries can be listed by `\dFd`, the
    # physical locations are in /usr/share/postgresql/<version>/tsearch_data.
    # But it may not appear there based on pg extension configuration.
    # base docker config
    #
    case locale.split("_")[0].to_sym
    when :da
      "danish"
    when :nl
      "dutch"
    when :en
      "english"
    when :fi
      "finnish"
    when :fr
      "french"
    when :de
      "german"
    when :hu
      "hungarian"
    when :it
      "italian"
    when :nb
      "norwegian"
    when :pt
      "portuguese"
    when :ro
      "romanian"
    when :ru
      "russian"
    when :es
      "spanish"
    when :sv
      "swedish"
    when :tr
      "turkish"
    else
      "simple" # use the 'simple' stemmer for other languages
    end
  end

  def self.unaccent(str)
    if SiteSetting.search_ignore_accents
      DB.query("SELECT unaccent(:str)", str: str)[0].unaccent
    else
      str
    end
  end

  def self.wrap_unaccent(expr)
    SiteSetting.search_ignore_accents ? "unaccent(#{expr})" : expr
  end

  def self.segment_chinese?
    %w[zh_TW zh_CN].include?(SiteSetting.default_locale) || SiteSetting.search_tokenize_chinese
  end

  def self.segment_japanese?
    SiteSetting.default_locale == "ja" || SiteSetting.search_tokenize_japanese
  end

  def self.japanese_punctuation_regexp
    # Regexp adapted from https://github.com/6/tiny_segmenter/blob/15a5b825993dfd2c662df3766f232051716bef5b/lib/tiny_segmenter.rb#L7
    @japanese_punctuation_regexp ||=
      Regexp.compile("[-–—―.。・（）()［］｛｝{}【】⟨⟩、､,，،…‥〽「」『』〜~！!：:？?\"'|_＿“”‘’;/⁄／«»]")
  end

  def self.clean_term(term)
    term = term.to_s.dup

    # Removes any zero-width characters from search terms
    term.gsub!(/[\u200B-\u200D\uFEFF]/, "")

    # Replace curly quotes to regular quotes
    term.gsub!(/[\u201c\u201d]/, '"')

    # Replace fancy apostophes to regular apostophes
    term.gsub!(/[\u02b9\u02bb\u02bc\u02bd\u02c8\u2018\u2019\u201b\u2032\uff07]/, "'")

    term
  end

  def self.prepare_data(search_data, purpose = nil)
    data = search_data.dup
    data.force_encoding("UTF-8")
    data = clean_term(data)

    if purpose != :topic && need_segmenting?(data)
      if segment_chinese?
        require "cppjieba_rb" unless defined?(CppjiebaRb)

        segmented_data = []

        # We need to split up the string here because Cppjieba has a bug where text starting with numeric chars will
        # be split into two segments. For example, '123abc' becomes '123' and 'abc' after segmentation.
        data.scan(/(?<chinese>[\p{Han}。,、“”《》…\.:?!;()]+)|([^\p{Han}]+)/) do
          match_data = $LAST_MATCH_INFO

          if match_data[:chinese]
            segments = CppjiebaRb.segment(match_data.to_s, mode: :mix)

            segments = CppjiebaRb.filter_stop_word(segments) if ts_config != "english"

            segments = segments.filter { |s| s.present? }
            segmented_data << segments.join(" ")
          else
            segmented_data << match_data.to_s.squish
          end
        end

        data = segmented_data.join(" ")
      elsif segment_japanese?
        data.gsub!(japanese_punctuation_regexp, " ")
        data = TinyJapaneseSegmenter.segment(data)
        data = data.filter { |s| s.present? }
        data = data.join(" ")
      else
        data.squish!
      end
    end

    data.gsub!(/\S+/) do |str|
      if str =~ %r{\A["]?((https?://)[\S]+)["]?\z}
        begin
          uri = URI.parse(Regexp.last_match[1])
          uri.query = nil
          str = uri.to_s
        rescue URI::Error
          # don't fail if uri does not parse
        end
      end

      str
    end

    data
  end

  def self.word_to_date(str)
    return Time.zone.now.beginning_of_day.days_ago(str.to_i) if str =~ /\A[0-9]{1,3}\z/

    if str =~ /\A([12][0-9]{3})(-([0-1]?[0-9]))?(-([0-3]?[0-9]))?\z/
      year = $1.to_i
      month = $2 ? $3.to_i : 1
      day = $4 ? $5.to_i : 1

      return if day == 0 || month == 0 || day > 31 || month > 12

      return(
        begin
          Time.zone.parse("#{year}-#{month}-#{day}")
        rescue ArgumentError
        end
      )
    end

    return Time.zone.now.beginning_of_day.yesterday if str.downcase == "yesterday"

    titlecase = str.downcase.titlecase

    if Date::DAYNAMES.include?(titlecase)
      return Time.zone.now.beginning_of_week(str.downcase.to_sym)
    end

    if idx = (Date::MONTHNAMES.find_index(titlecase) || Date::ABBR_MONTHNAMES.find_index(titlecase))
      delta = Time.zone.now.month - idx
      delta += 12 if delta < 0
      Time.zone.now.beginning_of_month.months_ago(delta)
    end
  end

  def self.min_post_id_no_cache
    return 0 unless SiteSetting.search_prefer_recent_posts?

    offset, has_more =
      Post
        .unscoped
        .order("id desc")
        .offset(SiteSetting.search_recent_posts_size - 1)
        .limit(2)
        .pluck(:id)

    has_more ? offset : 0
  end

  def self.min_post_id(opts = nil)
    return 0 unless SiteSetting.search_prefer_recent_posts?

    # It can be quite slow to count all the posts so let's cache it
    Discourse
      .cache
      .fetch("search-min-post-id:#{SiteSetting.search_recent_posts_size}", expires_in: 1.week) do
        min_post_id_no_cache
      end
  end

  def self.need_segmenting?(data)
    return false if data.match?(/\A\d+\z/)
    !URI.parse(data).path.to_s.start_with?("/")
  rescue URI::InvalidURIError
    true
  end

  attr_accessor :term
  attr_reader :clean_term, :guardian

  def initialize(term, opts = nil)
    @opts = opts || {}
    @guardian = @opts[:guardian] || Guardian.new
    @search_context = @opts[:search_context]
    @blurb_length = @opts[:blurb_length]
    @valid = true
    @page = @opts[:page]
    @search_all_pms = false

    term = Search.clean_term(term)

    @clean_term = term
    @in_title = false

    term = process_advanced_search!(term)
    if !@order &&
         SiteSetting.search_default_sort_order !=
           SearchSortOrderSiteSetting.value_from_id(:relevance)
      @order = SearchSortOrderSiteSetting.id_from_value(SiteSetting.search_default_sort_order)
    end

    if term.present?
      @term = Search.prepare_data(term, Topic === @search_context ? :topic : nil)
      @original_term = Search.escape_string(@term)
    end

    if @search_pms || @search_all_pms || @opts[:type_filter] == "private_messages"
      @opts[:type_filter] = "private_messages"
      @search_context ||= @guardian.user

      unless @search_context.present? && @guardian.can_see_private_messages?(@search_context.id)
        raise Discourse::InvalidAccess.new
      end
    end

    @opts[:type_filter] = "all_topics" if @search_all_topics && @guardian.user

    @results =
      GroupedSearchResults.new(
        type_filter: @opts[:type_filter],
        term: clean_term,
        blurb_term: term,
        search_context: @search_context,
        blurb_length: @blurb_length,
        is_header_search: !use_full_page_limit,
        can_lazy_load_categories: @guardian.can_lazy_load_categories?,
      )
  end

  def limit
    if use_full_page_limit
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

  def use_full_page_limit
    @opts[:search_type] == :full_page || Topic === @search_context
  end

  def self.execute(term, opts = nil)
    self.new(term, opts).execute
  end

  # Query a term
  def execute(readonly_mode: Discourse.readonly_mode?)
    if log_query?(readonly_mode)
      status, search_log_id =
        SearchLog.log(
          term: @clean_term,
          search_type: @opts[:search_type],
          ip_address: @opts[:ip_address],
          user_agent: @opts[:user_agent],
          user_id: @opts[:user_id],
        )
      @results.search_log_id = search_log_id unless status == :error
    end

    unless @filters.present? || @opts[:search_for_id]
      min_length = min_search_term_length
      terms = (@term || "").split(/\s(?=(?:[^"]|"[^"]*")*$)/).reject { |t| t.length < min_length }

      if terms.blank?
        @term = ""
        @valid = false
        return
      end
    end

    # If the term is a number or url to a topic, just include that topic
    if @opts[:search_for_id] && %w[topic private_messages all_topics].include?(@results.type_filter)
      if @term =~ /\A\d+\z/
        single_topic(@term.to_i)
      else
        if route = Discourse.route_for(@term)
          if route[:controller] == "topics" && route[:action] == "show"
            topic_id = (route[:id] || route[:topic_id]).to_i
            single_topic(topic_id) if topic_id > 0
          end
        end
      end
    end

    find_grouped_results if @results.posts.blank?

    if preloaded_topic_custom_fields.present? && @results.posts.present?
      topics = @results.posts.map(&:topic)
      Topic.preload_custom_fields(topics, preloaded_topic_custom_fields)
    end

    Search.preload(@results, self)

    @results
  end

  def self.advanced_order(trigger, &block)
    advanced_orders[trigger] = block
  end

  def self.advanced_orders
    @advanced_orders ||= {}
  end

  def self.advanced_filter(trigger, &block)
    advanced_filters[trigger] = block
  end

  def self.advanced_filters
    @advanced_filters ||= {}
  end

  def self.custom_topic_eager_load(tables = nil, &block)
    (@custom_topic_eager_loads ||= []) << (tables || block)
  end

  def self.custom_topic_eager_loads
    Array.wrap(@custom_topic_eager_loads)
  end

  advanced_filter(/\Ain:personal-direct\z/i) do |posts|
    if @guardian.user
      posts.joins("LEFT JOIN topic_allowed_groups tg ON posts.topic_id = tg.topic_id").where(
        <<~SQL,
          tg.id IS NULL
          AND posts.topic_id IN (
            SELECT tau.topic_id
            FROM topic_allowed_users tau
            JOIN topic_allowed_users tau2
            ON tau2.topic_id = tau.topic_id
            AND tau2.id != tau.id
            WHERE tau.user_id = :user_id
            GROUP BY tau.topic_id
            HAVING COUNT(*) = 1
          )
        SQL
        user_id: @guardian.user.id,
      )
    end
  end

  advanced_filter(/\Ain:all-pms\z/i) { |posts| posts.private_posts if @guardian.is_admin? }

  advanced_filter(/\Ain:tagged\z/i) do |posts|
    posts.where("EXISTS (SELECT 1 FROM topic_tags WHERE topic_tags.topic_id = posts.topic_id)")
  end

  advanced_filter(/\Ain:untagged\z/i) do |posts|
    posts.joins(
      "LEFT JOIN topic_tags ON
        topic_tags.topic_id = posts.topic_id",
    ).where("topic_tags.id IS NULL")
  end

  advanced_filter(/\Astatus:open\z/i) do |posts|
    posts.where("NOT topics.closed AND NOT topics.archived")
  end

  advanced_filter(/\Astatus:closed\z/i) { |posts| posts.where("topics.closed") }

  advanced_filter(/\Astatus:public\z/i) do |posts|
    category_ids = Category.where(read_restricted: false).pluck(:id)

    posts.where("topics.category_id in (?)", category_ids)
  end

  advanced_filter(/\Astatus:archived\z/i) { |posts| posts.where("topics.archived") }

  advanced_filter(/\Astatus:noreplies\z/i) { |posts| posts.where("topics.posts_count = 1") }

  advanced_filter(/\Astatus:single_user\z/i) { |posts| posts.where("topics.participant_count = 1") }

  advanced_filter(/\Aposts_count:(\d+)\z/i) do |posts, match|
    posts.where("topics.posts_count = ?", match.to_i)
  end

  advanced_filter(/\Amin_post_count:(\d+)\z/i) do |posts, match|
    posts.where("topics.posts_count >= ?", match.to_i)
  end

  advanced_filter(/\Amin_posts:(\d+)\z/i) do |posts, match|
    posts.where("topics.posts_count >= ?", match.to_i)
  end

  advanced_filter(/\Amax_posts:(\d+)\z/i) do |posts, match|
    posts.where("topics.posts_count <= ?", match.to_i)
  end

  advanced_filter(/\Ain:first|^f\z/i) { |posts| posts.where("posts.post_number = 1") }

  advanced_filter(/\Ain:pinned\z/i) { |posts| posts.where("topics.pinned_at IS NOT NULL") }

  advanced_filter(/\Ain:wiki\z/i) { |posts, match| posts.where(wiki: true) }

  advanced_filter(/\Abadge:(.*)\z/i) do |posts, match|
    badge_id = Badge.where("name ilike ? OR id = ?", match, match.to_i).pick(:id)
    if badge_id
      posts.where(
        "posts.user_id IN (SELECT ub.user_id FROM user_badges ub WHERE ub.badge_id = ?)",
        badge_id,
      )
    else
      posts.where("1 = 0")
    end
  end

  def post_action_type_filter(posts, post_action_type)
    posts.where(
      "posts.id IN (
      SELECT pa.post_id FROM post_actions pa
      WHERE pa.user_id = ? AND
            pa.post_action_type_id = ? AND
            deleted_at IS NULL
    )",
      @guardian.user.id,
      post_action_type,
    )
  end

  advanced_filter(/\Ain:(likes)\z/i) do |posts, match|
    post_action_type_filter(posts, PostActionType.types[:like]) if @guardian.user
  end

  # NOTE: With polymorphic bookmarks it may make sense to possibly expand
  # this at some point, as it only acts on posts at the moment. On the other
  # hand, this may not be necessary, as the user bookmark list has advanced
  # search based on a RegisteredBookmarkable's #search_query method.
  advanced_filter(/\Ain:(bookmarks)\z/i) do |posts, match|
    posts.where(<<~SQL, @guardian.user.id) if @guardian.user
        posts.id IN (
          SELECT bookmarkable_id FROM bookmarks
          WHERE bookmarks.user_id = ? AND bookmarks.bookmarkable_type = 'Post'
        )
      SQL
  end

  advanced_filter(/\Ain:posted\z/i) do |posts|
    posts.where("posts.user_id = ?", @guardian.user.id) if @guardian.user
  end

  advanced_filter(/\Ain:(created|mine)\z/i) do |posts|
    posts.where(user_id: @guardian.user.id, post_number: 1) if @guardian.user
  end

  advanced_filter(/\Acreated:@(.*)\z/i) do |posts, match|
    user_id = User.where(username_lower: match.downcase).pick(:id)
    posts.where(user_id: user_id, post_number: 1)
  end

  advanced_filter(/\Ain:(watching|tracking)\z/i) do |posts, match|
    if @guardian.user
      level = TopicUser.notification_levels[match.downcase.to_sym]
      posts.where(
        "posts.topic_id IN (
                    SELECT tu.topic_id FROM topic_users tu
                    WHERE tu.user_id = :user_id AND
                          tu.notification_level >= :level
                   )",
        user_id: @guardian.user.id,
        level: level,
      )
    end
  end

  advanced_filter(/\Ain:seen\z/i) do |posts|
    if @guardian.user
      posts.joins(
        "INNER JOIN post_timings ON
          post_timings.topic_id = posts.topic_id
          AND post_timings.post_number = posts.post_number
          AND post_timings.user_id = #{ActiveRecord::Base.connection.quote(@guardian.user.id)}
        ",
      )
    end
  end

  advanced_filter(/\Ain:unseen\z/i) do |posts|
    if @guardian.user
      posts.joins(
        "LEFT JOIN post_timings ON
          post_timings.topic_id = posts.topic_id
          AND post_timings.post_number = posts.post_number
          AND post_timings.user_id = #{ActiveRecord::Base.connection.quote(@guardian.user.id)}
        ",
      ).where("post_timings.user_id IS NULL")
    end
  end

  advanced_filter(/\Awith:images\z/i) { |posts| posts.where("posts.image_upload_id IS NOT NULL") }

  advanced_filter(/\Acategor(?:y|ies):(.+)\z/i) do |posts, terms|
    category_ids = []

    matches =
      terms
        .split(",")
        .map do |term|
          if term[0] == "="
            [term[1..-1], true]
          else
            [term, false]
          end
        end
        .to_h

    if matches.present?
      sql = <<~SQL
      SELECT c.id, term
      FROM
          categories c
      JOIN
          unnest(ARRAY[:matches]) AS term ON
          c.slug ILIKE term OR
          c.name ILIKE term OR
          (term ~ '^[0-9]{1,10}$' AND c.id = term::int)
      SQL

      found = DB.query(sql, matches: matches.keys)

      if found.present?
        found.each do |row|
          category_ids << row.id
          @category_filter_matched ||= true
          category_ids += Category.subcategory_ids(row.id) if !matches[row.term]
        end
      end
    end

    if category_ids.present?
      posts.where("topics.category_id IN (?)", category_ids.uniq)
    else
      posts.where("1 = 0")
    end
  end

  advanced_filter(/\A\#([\p{L}\p{M}0-9\-:=]+)\z/i) do |posts, match|
    category_slug, subcategory_slug = match.to_s.split(":")
    next unless category_slug

    exact = true
    if category_slug[0] == "="
      category_slug = category_slug[1..-1]
    else
      exact = false
    end

    category_id =
      if subcategory_slug
        Category
          .where("lower(slug) = ?", subcategory_slug.downcase)
          .where(
            parent_category_id:
              Category.where("lower(slug) = ?", category_slug.downcase).select(:id),
          )
          .pick(:id)
      else
        Category
          .where("lower(slug) = ?", category_slug.downcase)
          .order("case when parent_category_id is null then 0 else 1 end")
          .pick(:id)
      end

    if category_id
      category_ids = [category_id]
      category_ids += Category.subcategory_ids(category_id) if !exact

      @category_filter_matched ||= true
      posts.where("topics.category_id IN (?)", category_ids)
    else
      # try a possible tag match
      tag_id = Tag.where_name(category_slug).pick(:id)
      if (tag_id)
        posts.where(<<~SQL, tag_id)
          topics.id IN (
            SELECT DISTINCT(tt.topic_id)
            FROM topic_tags tt
            WHERE tt.tag_id = ?
          )
        SQL
      else
        if tag_group_id = TagGroup.find_id_by_slug(category_slug)
          posts.where(<<~SQL, tag_group_id)
            topics.id IN (
              SELECT DISTINCT(tt.topic_id)
              FROM topic_tags tt
              WHERE tt.tag_id in (
                SELECT tag_id
                FROM tag_group_memberships
                WHERE tag_group_id = ?
              )
            )
          SQL

          # a bit yucky but we got to add the term back in
        elsif match.to_s.length >= min_search_term_length
          posts.where <<~SQL
            posts.id IN (
              SELECT post_id FROM post_search_data pd1
              WHERE pd1.search_data @@ #{Search.ts_query(term: "##{match}")})
          SQL
        end
      end
    end
  end

  advanced_filter(/\Agroup:(.+)\z/i) do |posts, match|
    group_query =
      Group
        .visible_groups(@guardian.user)
        .members_visible_groups(@guardian.user)
        .where("groups.name ILIKE ? OR (groups.id = ? AND groups.id > 0)", match, match.to_i)

    DiscoursePluginRegistry.search_groups_set_query_callbacks.each do |cb|
      group_query = cb.call(group_query, @term, @guardian)
    end

    group_id = group_query.pick(:id)

    if group_id
      posts.where(
        "posts.user_id IN (select gu.user_id from group_users gu where gu.group_id = ?)",
        group_id,
      )
    else
      posts.where("1 = 0")
    end
  end

  advanced_filter(/\Agroup_messages:(.+)\z/i) do |posts, match|
    group_id =
      Group
        .visible_groups(@guardian.user)
        .members_visible_groups(@guardian.user)
        .where(has_messages: true)
        .where("name ilike ? OR (id = ? AND id > 0)", match, match.to_i)
        .pick(:id)

    if group_id
      posts.where(
        "posts.topic_id IN (SELECT topic_id FROM topic_allowed_groups WHERE group_id = ?)",
        group_id,
      )
    else
      posts.where("1 = 0")
    end
  end

  advanced_filter(/\Auser:(.+)\z/i) do |posts, match|
    user_id =
      User
        .where(staged: false)
        .where("username_lower = ? OR id = ?", match.downcase, match.to_i)
        .pick(:id)
    if user_id
      posts.where("posts.user_id = ?", user_id)
    else
      posts.where("1 = 0")
    end
  end

  advanced_filter(/\A\@(\S+)\z/i) do |posts, match|
    username = User.normalize_username(match)

    user_id = User.not_staged.where(username_lower: username).pick(:id)

    user_id = @guardian.user&.id if !user_id && username == "me"

    if user_id
      posts.where("posts.user_id = ?", user_id)
    else
      posts.where("1 = 0")
    end
  end

  advanced_filter(/\Abefore:(.*)\z/i) do |posts, match|
    if date = Search.word_to_date(match)
      posts.where("posts.created_at < ?", date)
    else
      posts
    end
  end

  advanced_filter(/\Aafter:(.*)\z/i) do |posts, match|
    if date = Search.word_to_date(match)
      posts.where("posts.created_at > ?", date)
    else
      posts
    end
  end

  advanced_filter(/\Atags?:([\p{L}\p{M}0-9,\-_+]+)\z/i) do |posts, match|
    search_tags(posts, match, positive: true)
  end

  advanced_filter(/\A\-tags?:([\p{L}\p{M}0-9,\-_+]+)\z/i) do |posts, match|
    search_tags(posts, match, positive: false)
  end

  advanced_filter(/\Afiletypes?:([a-zA-Z0-9,\-_]+)\z/i) do |posts, match|
    file_extensions = match.split(",").map(&:downcase)
    posts.where(
      "posts.id IN (
      SELECT post_id
        FROM topic_links
       WHERE extension IN (:file_extensions)

      UNION

      SELECT upload_references.target_id
        FROM uploads
        JOIN upload_references ON upload_references.target_type = 'Post' AND upload_references.upload_id = uploads.id
       WHERE lower(uploads.extension) IN (:file_extensions)
    )",
      file_extensions: file_extensions,
    )
  end

  advanced_filter(/\Amin_views:(\d+)\z/i) do |posts, match|
    posts.where("topics.views >= ?", match.to_i)
  end

  advanced_filter(/\Amax_views:(\d+)\z/i) do |posts, match|
    posts.where("topics.views <= ?", match.to_i)
  end

  def apply_filters(posts)
    @filters.each do |block, match|
      if block.arity == 1
        posts = instance_exec(posts, &block) || posts
      else
        posts = instance_exec(posts, match, &block) || posts
      end
    end if @filters
    posts
  end

  def apply_order(
    posts,
    aggregate_search: false,
    allow_relevance_search: true,
    type_filter: "all_topics"
  )
    if @order == :latest
      if aggregate_search
        posts = posts.order("MAX(posts.created_at) DESC")
      else
        posts = posts.reorder("posts.created_at DESC")
      end
    elsif @order == :oldest
      if aggregate_search
        posts = posts.order("MAX(posts.created_at) ASC")
      else
        posts = posts.reorder("posts.created_at ASC")
      end
    elsif @order == :latest_topic
      if aggregate_search
        posts = posts.order("MAX(topics.created_at) DESC")
      else
        posts = posts.order("topics.created_at DESC")
      end
    elsif @order == :oldest_topic
      if aggregate_search
        posts = posts.order("MAX(topics.created_at) ASC")
      else
        posts = posts.order("topics.created_at ASC")
      end
    elsif @order == :views
      if aggregate_search
        posts = posts.order("MAX(topics.views) DESC")
      else
        posts = posts.order("topics.views DESC")
      end
    elsif @order == :likes
      if aggregate_search
        posts = posts.order("MAX(posts.like_count) DESC")
      else
        posts = posts.order("posts.like_count DESC")
      end
    elsif allow_relevance_search
      posts = sort_by_relevance(posts, type_filter: type_filter, aggregate_search: aggregate_search)
    end

    if @order
      advanced_order = Search.advanced_orders&.fetch(@order, nil)
      posts = advanced_order.call(posts) if advanced_order
    end

    posts
  end

  private

  def search_tags(posts, match, positive:)
    return if match.nil?
    match.downcase!
    modifier = positive ? "" : "NOT"

    if match.include?("+")
      tags = match.split("+")

      posts.where(
        "topics.id #{modifier} IN (
        SELECT tt.topic_id
        FROM topic_tags tt, tags
        WHERE tt.tag_id = tags.id
        GROUP BY tt.topic_id
        HAVING to_tsvector(#{default_ts_config}, #{Search.wrap_unaccent("array_to_string(array_agg(lower(tags.name)), ' ')")}) @@ to_tsquery(#{default_ts_config}, ?)
      )",
        Search.unaccent(tags.join("&")),
      )
    else
      tags = match.split(",")

      posts.where(
        "topics.id #{modifier} IN (
        SELECT DISTINCT(tt.topic_id)
        FROM topic_tags tt, tags
        WHERE tt.tag_id = tags.id AND lower(tags.name) IN (?)
      )",
        tags,
      )
    end
  end

  def process_advanced_search!(term)
    term
      .to_s
      .scan(/(([^" \t\n\x0B\f\r]+)?(("[^"]+")?))/)
      .to_a
      .map do |(word, _)|
        next if word.blank?

        found = false

        Search.advanced_filters.each do |matcher, block|
          case_insensitive_matcher =
            Regexp.new(matcher.source, matcher.options | Regexp::IGNORECASE)

          cleaned = word.gsub(/["']/, "")
          if cleaned =~ case_insensitive_matcher
            (@filters ||= []) << [block, $1]
            found = true
          end
        end

        if word == "l"
          @order = :latest
          nil
        elsif word =~ /\Aorder:\w+\z/i
          @order = word.downcase.gsub("order:", "").to_sym
          nil
        elsif word =~ /\Ain:title\z/i || word == "t"
          @in_title = true
          nil
        elsif word =~ /\Atopic:(\d+)\z/i
          topic_id = $1.to_i
          if topic_id > 1
            topic = Topic.find_by(id: topic_id)
            @search_context = topic if @guardian.can_see?(topic)
          end
          nil
        elsif word =~ /\Ain:all\z/i
          @search_all_topics = true
          nil
        elsif word =~ /\Ain:personal\z/i
          @search_pms = true
          nil
        elsif word =~ /\Ain:messages\z/i
          @search_pms = true
          nil
        elsif word =~ /\Ain:personal-direct\z/i
          @search_pms = true
          nil
        elsif word =~ /\Ain:all-pms\z/i
          @search_all_pms = true
          nil
        elsif word =~ /\Agroup_messages:(.+)\z/i
          @search_pms = true
          nil
        elsif word =~ /\Apersonal_messages:(.+)\z/i
          if user = User.find_by_username($1)
            @search_pms = true
            @search_context = user
          end

          nil
        elsif word =~ /\Ainclude:(invisible|unlisted)\z/i
          @include_invisible = true if @guardian.can_see_unlisted_topics?
          nil
        else
          found ? nil : word
        end
      end
      .compact
      .join(" ")
  end

  def find_grouped_results
    if @results.type_filter.present?
      if Search.facets.exclude?(@results.type_filter)
        raise Discourse::InvalidAccess.new("invalid type filter")
      end
      # calling protected methods
      send("#{@results.type_filter}_search")
    else
      if @term.present? && !@search_context
        user_search
        category_search
        tags_search
        groups_search
      end
      topic_search
    end

    @results
  rescue ActiveRecord::StatementInvalid
    # In the event of a PG:Error return nothing, it is likely they used a foreign language whose
    # locale is not supported by postgres
  end

  # If we're searching for a single topic
  def single_topic(id)
    if @opts[:restrict_to_archetype].present?
      archetype =
        (
          if @opts[:restrict_to_archetype] == Archetype.default
            Archetype.default
          else
            Archetype.private_message
          end
        )

      post =
        posts_scope.joins(:topic).find_by(
          "topics.id = :id AND topics.archetype = :archetype AND posts.post_number = 1",
          id: id,
          archetype: archetype,
        )
    else
      post = posts_scope.find_by(topic_id: id, post_number: 1)
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

    categories =
      Category
        .includes(:category_search_data)
        .where("category_search_data.search_data @@ #{ts_query}")
        .references(:category_search_data)
        .order("topics_month DESC")
        .secured(@guardian)
        .limit(limit)

    categories.each { |category| @results.add(category) }
  end

  def user_search
    return if SiteSetting.hide_user_profiles_from_public && !@guardian.user

    users =
      User
        .includes(:user_search_data)
        .references(:user_search_data)
        .where(active: true)
        .where(staged: false)
        .where("user_search_data.search_data @@ #{ts_query("simple")}")
        .order("CASE WHEN username_lower = '#{@original_term.downcase}' THEN 0 ELSE 1 END")
        .order("last_posted_at DESC")
        .limit(limit)

    if !SiteSetting.enable_listing_suspended_users_on_search && !@guardian.user&.admin
      users = users.where(suspended_at: nil)
    end

    users = DiscoursePluginRegistry.apply_modifier(:search_user_search, users)

    users_custom_data_query =
      DB.query(<<~SQL, user_ids: users.pluck(:id), term: "%#{@original_term.downcase}%")
      SELECT user_custom_fields.user_id, user_fields.name, user_custom_fields.value FROM user_custom_fields
      INNER JOIN user_fields ON user_fields.id = REPLACE(user_custom_fields.name, 'user_field_', '')::INTEGER AND user_fields.searchable IS TRUE
      WHERE user_id IN (:user_ids)
      AND user_custom_fields.name LIKE 'user_field_%'
      AND user_custom_fields.value ILIKE :term
    SQL
    users_custom_data =
      users_custom_data_query.reduce({}) do |acc, row|
        acc[row.user_id] = Array.wrap(acc[row.user_id]) << { name: row.name, value: row.value }
        acc
      end

    users.each do |user|
      user.custom_data = users_custom_data[user.id] || []
      @results.add(user)
    end
  end

  def groups_search
    group_query =
      Group.visible_groups(@guardian.user, "groups.name ASC", include_everyone: false).where(
        "groups.name ILIKE :term OR groups.full_name ILIKE :term",
        term: "%#{@term}%",
      )

    DiscoursePluginRegistry.search_groups_set_query_callbacks.each do |cb|
      group_query = cb.call(group_query, @term, @guardian)
    end

    groups = group_query.limit(limit)

    groups.each { |group| @results.add(group) }
  end

  def tags_search
    return unless SiteSetting.tagging_enabled
    tags =
      Tag
        .includes(:tag_search_data)
        .where("tag_search_data.search_data @@ #{ts_query}")
        .references(:tag_search_data)
        .order("name asc")
        .limit(limit)

    hidden_tag_names = DiscourseTagging.hidden_tag_names(@guardian)

    tags.each { |tag| @results.add(tag) if !hidden_tag_names.include?(tag.name) }
  end

  def exclude_topics_search
    if @term.present?
      user_search
      category_search
      tags_search
      groups_search
    end
  end

  PHRASE_MATCH_REGEXP_PATTERN = '"([^"]+)"'

  def posts_query(limit, type_filter: nil, aggregate_search: false)
    posts =
      Post.where(post_type: Topic.visible_post_types(@guardian.user), hidden: false).joins(
        :post_search_data,
        :topic,
      )

    if type_filter != "private_messages"
      posts = posts.joins("LEFT JOIN categories ON categories.id = topics.category_id")
    end

    is_topic_search = @search_context.present? && @search_context.is_a?(Topic)
    posts = posts.where("topics.visible") unless is_topic_search || @include_invisible

    if type_filter == "private_messages" || (is_topic_search && @search_context.private_message?)
      posts =
        posts.where(
          "topics.archetype = ? AND post_search_data.private_message",
          Archetype.private_message,
        )

      posts = posts.private_posts_for_user(@guardian.user) unless @guardian.is_admin?
    elsif type_filter == "all_topics"
      private_posts =
        posts.where(
          "topics.archetype = ? AND post_search_data.private_message",
          Archetype.private_message,
        ).private_posts_for_user(@guardian.user)

      posts =
        posts.where(
          "topics.archetype <> ? AND NOT post_search_data.private_message",
          Archetype.private_message,
        ).or(private_posts)
    else
      posts =
        posts.where(
          "topics.archetype <> ? AND NOT post_search_data.private_message",
          Archetype.private_message,
        )
    end

    if @term.present?
      if is_topic_search
        term_without_quote = @term
        term_without_quote = $1 if @term =~ /"(.+)"/

        term_without_quote = $1 if @term =~ /'(.+)'/

        posts = posts.joins("JOIN users u ON u.id = posts.user_id")
        posts =
          posts.where(
            "posts.raw  || ' ' || u.username || ' ' || COALESCE(u.name, '') ilike ?",
            "%#{term_without_quote}%",
          )
      else
        posts = posts.where(post_number: 1) if @in_title
        posts = posts.where("post_search_data.search_data @@ #{ts_query(weight_filter: weights)}")
        exact_terms = @term.scan(Regexp.new(PHRASE_MATCH_REGEXP_PATTERN)).flatten

        exact_terms.each do |exact|
          posts =
            posts.where("posts.raw ilike :exact OR topics.title ilike :exact", exact: "%#{exact}%")
        end
      end
    end

    posts = apply_filters(posts)

    # If we have a search context, prioritize those posts first
    posts =
      if @search_context.present?
        if @search_context.is_a?(User)
          if type_filter == "private_messages"
            if @guardian.is_admin? && !@search_all_pms
              posts.private_posts_for_user(@search_context)
            else
              posts
            end
          else
            posts.where("posts.user_id = #{@search_context.id}")
          end
        elsif @search_context.is_a?(Category)
          category_ids =
            Category
              .where(parent_category_id: @search_context.id)
              .pluck(:id)
              .push(@search_context.id)

          posts.where("topics.category_id in (?)", category_ids)
        elsif is_topic_search
          posts = posts.where("topics.id = ?", @search_context.id)
          posts = posts.order("posts.post_number ASC") unless @order
          posts
        elsif @search_context.is_a?(Tag)
          posts =
            posts.joins("LEFT JOIN topic_tags ON topic_tags.topic_id = topics.id").joins(
              "LEFT JOIN tags ON tags.id = topic_tags.tag_id",
            )
          posts.where("tags.id = ?", @search_context.id)
        end
      else
        posts = categories_ignored(posts) unless @category_filter_matched
        posts
      end

    if type_filter != "private_messages"
      posts =
        if secure_category_ids.present?
          posts.where(
            "(categories.id IS NULL) OR (NOT categories.read_restricted) OR (categories.id IN (?))",
            secure_category_ids,
          ).references(:categories)
        else
          posts.where("(categories.id IS NULL) OR (NOT categories.read_restricted)").references(
            :categories,
          )
        end
    end

    posts =
      apply_order(
        posts,
        aggregate_search: aggregate_search,
        allow_relevance_search: !is_topic_search,
        type_filter: type_filter,
      )

    posts = posts.offset(offset)
    posts.limit(limit)
  end

  def weights
    # A is for title
    # B is for category
    # C is for tags
    # D is for cooked
    @in_title ? "A" : (SiteSetting.tagging_enabled ? "ABCD" : "ABD")
  end

  def sort_by_relevance(posts, type_filter:, aggregate_search:)
    exact_rank = nil

    if SiteSetting.prioritize_exact_search_title_match
      exact_rank = ts_rank_cd(weight_filter: "A", prefix_match: false)
    end

    rank = ts_rank_cd(weight_filter: weights)

    if type_filter != "private_messages"
      category_search_priority = <<~SQL
        (
          CASE categories.search_priority
          WHEN #{Searchable::PRIORITIES[:very_high]}
          THEN 3
          WHEN #{Searchable::PRIORITIES[:very_low]}
          THEN 1
          ELSE 2
          END
        )
        SQL

      rank_sort_priorities = [["topics.archived", 0.85], ["topics.closed", 0.9]]

      rank_sort_priorities =
        DiscoursePluginRegistry.apply_modifier(
          :search_rank_sort_priorities,
          rank_sort_priorities,
          self,
        )

      category_priority_weights = <<~SQL
          (
            CASE categories.search_priority
              WHEN #{Searchable::PRIORITIES[:low]}
              THEN #{SiteSetting.category_search_priority_low_weight.to_f}
              WHEN #{Searchable::PRIORITIES[:high]}
              THEN #{SiteSetting.category_search_priority_high_weight.to_f}
              ELSE 1.0
            END
            *
            CASE
              #{rank_sort_priorities.sort_by { |_, pri| -pri }.map { |k, v| "WHEN #{k} THEN #{v}" }.join("\n")}
              ELSE 1.0
            END
          )
        SQL

      posts =
        if aggregate_search
          posts.order("MAX(#{category_search_priority}) DESC")
        else
          posts.order("#{category_search_priority} DESC")
        end

      if @term.present? && exact_rank
        posts =
          if aggregate_search
            posts.order("MAX(#{exact_rank} * #{category_priority_weights}) DESC")
          else
            posts.order("#{exact_rank} * #{category_priority_weights} DESC")
          end
      end

      data_ranking =
        if @term.blank?
          "(#{category_priority_weights})"
        else
          "(#{rank} * #{category_priority_weights})"
        end

      posts =
        if aggregate_search
          posts.order("MAX(#{data_ranking}) DESC")
        else
          posts.order("#{data_ranking} DESC")
        end
    end

    posts.order("topics.bumped_at DESC")
  end

  def ts_rank_cd(weight_filter:, prefix_match: true)
    <<~SQL
      TS_RANK_CD(
        #{SiteSetting.search_ranking_weights.present? ? "'#{SiteSetting.search_ranking_weights}'," : ""}
        post_search_data.search_data,
        #{@term.blank? ? "" : ts_query(weight_filter: weight_filter, prefix_match: prefix_match)},
        #{SiteSetting.search_ranking_normalization}|32
      )
      SQL
  end

  def categories_ignored(posts)
    posts.where(<<~SQL, Searchable::PRIORITIES[:ignore])
    (categories.search_priority IS NULL OR categories.search_priority IS NOT NULL AND categories.search_priority <> ?)
    SQL
  end

  def self.default_ts_config
    "'#{Search.ts_config}'"
  end

  def default_ts_config
    self.class.default_ts_config
  end

  def self.ts_query(term:, ts_config: nil, joiner: nil, weight_filter: nil, prefix_match: true)
    to_tsquery(
      ts_config: ts_config,
      term: set_tsquery_weight_filter(term, weight_filter, prefix_match: prefix_match),
    )
  end

  def self.to_tsquery(ts_config: nil, term:, joiner: nil)
    ts_config = ActiveRecord::Base.connection.quote(ts_config) if ts_config
    escaped_term = "'#{escape_string(unaccent(term))}'"
    tsquery = "TO_TSQUERY(#{ts_config || default_ts_config}, #{escaped_term})"
    # PG 14 and up default to using the followed by operator
    # this restores the old behavior
    tsquery = "REGEXP_REPLACE(#{tsquery}::text, '<->|<\\d+>', '&', 'g')::tsquery"
    tsquery = "REPLACE(#{tsquery}::text, '&', '#{escape_string(joiner)}')::tsquery" if joiner
    tsquery
  end

  def self.set_tsquery_weight_filter(term, weight_filter, prefix_match: true)
    "'#{self.escape_string(term)}':#{prefix_match ? "*" : ""}#{weight_filter}"
  end

  def self.escape_string(term)
    PG::Connection.escape_string(term).gsub('\\', '\\\\\\')
  end

  def ts_query(ts_config = nil, weight_filter: nil, prefix_match: true)
    @ts_query_cache ||= {}
    @ts_query_cache[
      "#{ts_config || default_ts_config} #{@term} #{weight_filter} #{prefix_match}"
    ] ||= Search.ts_query(
      term: @term,
      ts_config: ts_config,
      weight_filter: weight_filter,
      prefix_match: prefix_match,
    )
  end

  def wrap_rows(query)
    "SELECT *, row_number() over() row_number FROM (#{query.to_sql}) xxx"
  end

  def aggregate_post_sql(opts)
    min_id =
      if SiteSetting.search_recent_regular_posts_offset_post_id > 0
        if %w[all_topics private_message].include?(opts[:type_filter])
          0
        else
          SiteSetting.search_recent_regular_posts_offset_post_id
        end
      else
        # This is kept around for backwards compatibility.
        # TODO: Drop this code path after Discourse 2.7 has been released.
        Search.min_post_id
      end

    min_or_max = @order == :latest ? "max" : "min"

    query =
      if @order == :likes
        # likes are a pain to aggregate so skip
        posts_query(limit, type_filter: opts[:type_filter]).select("topics.id", "posts.post_number")
      else
        posts_query(limit, aggregate_search: true, type_filter: opts[:type_filter]).select(
          "topics.id",
          "#{min_or_max}(posts.post_number) post_number",
        ).group("topics.id")
      end

    if min_id > 0
      low_set = query.dup.where("post_search_data.post_id < ?", min_id)
      high_set = query.where("post_search_data.post_id >= ?", min_id)

      return { default: wrap_rows(high_set), remaining: wrap_rows(low_set) }
    end

    # double wrapping so we get correct row numbers
    { default: wrap_rows(query) }
  end

  def aggregate_posts(post_sql)
    return [] unless post_sql

    posts_scope(posts_eager_loads(Post)).joins(
      "JOIN (#{post_sql}) x ON x.id = posts.topic_id AND x.post_number = posts.post_number",
    ).order("row_number")
  end

  def aggregate_search(opts = {})
    post_sql = aggregate_post_sql(opts)

    added = 0

    aggregate_posts(post_sql[:default]).each do |p|
      @results.add(p)
      added += 1
    end

    aggregate_posts(post_sql[:remaining]).each { |p| @results.add(p) } if added < limit
  end

  def private_messages_search
    raise Discourse::InvalidAccess.new("anonymous can not search PMs") unless @guardian.user

    aggregate_search(type_filter: "private_messages")
  end

  def all_topics_search
    aggregate_search(type_filter: "all_topics")
  end

  def topic_search
    if @search_context.is_a?(Topic)
      posts =
        posts_scope(posts_eager_loads(posts_query(limit))).where(
          "posts.topic_id = ?",
          @search_context.id,
        )

      posts.each { |post| @results.add(post) }
    else
      aggregate_search
    end
  end

  def posts_eager_loads(query)
    query = query.includes(:user, :post_search_data)
    topic_eager_loads = [{ category: :parent_category }]

    topic_eager_loads << :tags if SiteSetting.tagging_enabled

    Search.custom_topic_eager_loads.each do |custom_loads|
      topic_eager_loads.concat(
        custom_loads.is_a?(Array) ? custom_loads : custom_loads.call(search_pms: @search_pms).to_a,
      )
    end

    query.includes(topic: topic_eager_loads)
  end

  # Limited for performance reasons since `TS_HEADLINE` is slow when the text
  # document is too long.
  MAX_LENGTH_FOR_HEADLINE = 2500

  def posts_scope(default_scope = Post.all)
    if SiteSetting.use_pg_headlines_for_excerpt
      search_term = @term.present? ? Search.escape_string(@term) : nil
      ts_config = default_ts_config

      default_scope
        .joins("INNER JOIN post_search_data pd ON pd.post_id = posts.id")
        .joins("INNER JOIN topics t1 ON t1.id = posts.topic_id")
        .select(
          "TS_HEADLINE(
            #{ts_config},
            t1.fancy_title,
            PLAINTO_TSQUERY(#{ts_config}, '#{search_term}'),
            'StartSel=''<span class=\"#{HIGHLIGHT_CSS_CLASS}\">'', StopSel=''</span>'', HighlightAll=true'
          ) AS topic_title_headline",
          "TS_HEADLINE(
            #{ts_config},
            LEFT(
              TS_HEADLINE(
                #{ts_config},
                LEFT(pd.raw_data, #{MAX_LENGTH_FOR_HEADLINE}),
                PLAINTO_TSQUERY(#{ts_config}, '#{search_term}'),
                'ShortWord=0, MaxFragments=1, MinWords=50, MaxWords=51, StartSel='''', StopSel='''''
              ),
              #{Search::GroupedSearchResults::BLURB_LENGTH}
            ),
            PLAINTO_TSQUERY(#{ts_config}, '#{search_term}'),
            'HighlightAll=true, StartSel=''<span class=\"#{HIGHLIGHT_CSS_CLASS}\">'', StopSel=''</span>'''
          ) AS headline",
          "LEFT(pd.raw_data, 50) AS leading_raw_data",
          "RIGHT(pd.raw_data, 50) AS trailing_raw_data",
          default_scope.arel.projections,
        )
    else
      default_scope
    end
  end

  def log_query?(readonly_mode)
    SiteSetting.log_search_queries? && @opts[:search_type].present? && !readonly_mode &&
      @opts[:type_filter] != "exclude_topics"
  end

  def min_search_term_length
    return @opts[:min_search_term_length] if @opts[:min_search_term_length]

    if SiteSetting.search_tokenize_chinese
      return SiteSetting.defaults.get("min_search_term_length", "zh_CN")
    end

    if SiteSetting.search_tokenize_japanese
      return SiteSetting.defaults.get("min_search_term_length", "ja")
    end

    SiteSetting.min_search_term_length
  end
end
