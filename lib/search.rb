# frozen_string_literal: true

class Search
  DIACRITICS ||= /([\u0300-\u036f]|[\u1AB0-\u1AFF]|[\u1DC0-\u1DFF]|[\u20D0-\u20FF])/
  HIGHLIGHT_CSS_CLASS = 'search-highlight'

  cattr_accessor :preloaded_topic_custom_fields
  self.preloaded_topic_custom_fields = Set.new

  def self.on_preload(&blk)
    (@preload ||= Set.new) << blk
  end

  def self.preload(results, object)
    if @preload
      @preload.each { |preload| preload.call(results, object) }
    end
  end

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

  def self.facets
    %w(topic category user private_messages tags all_topics exclude_topics)
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
    when :da then 'danish'
    when :nl then 'dutch'
    when :en then 'english'
    when :fi then 'finnish'
    when :fr then 'french'
    when :de then 'german'
    when :hu then 'hungarian'
    when :it then 'italian'
    when :nb then 'norwegian'
    when :pt then 'portuguese'
    when :ro then 'romanian'
    when :ru then 'russian'
    when :es then 'spanish'
    when :sv then 'swedish'
    when :tr then 'turkish'
    else 'simple' # use the 'simple' stemmer for other languages
    end
  end

  def self.segment_chinese?
    ['zh_TW', 'zh_CN'].include?(SiteSetting.default_locale) || SiteSetting.search_tokenize_chinese
  end

  def self.segment_japanese?
    SiteSetting.default_locale == "ja" || SiteSetting.search_tokenize_japanese
  end

  def self.japanese_punctuation_regexp
    # Regexp adapted from https://github.com/6/tiny_segmenter/blob/15a5b825993dfd2c662df3766f232051716bef5b/lib/tiny_segmenter.rb#L7
    @japanese_punctuation_regexp ||= Regexp.compile("[-–—―.。・（）()［］｛｝{}【】⟨⟩、､,，،…‥〽「」『』〜~！!：:？?\"'|_＿“”‘’;/⁄／«»]")
  end

  def self.prepare_data(search_data, purpose = nil)
    data = search_data.dup
    data.force_encoding("UTF-8")

    if purpose != :topic
      if segment_chinese?
        require 'cppjieba_rb' unless defined? CppjiebaRb

        segmented_data = []

        # We need to split up the string here because Cppjieba has a bug where text starting with numeric chars will
        # be split into two segments. For example, '123abc' becomes '123' and 'abc' after segmentation.
        data.scan(/(?<chinese>[\p{Han}。,、“”《》…\.:?!;()]+)|([^\p{Han}]+)/) do
          match_data = $LAST_MATCH_INFO

          if match_data[:chinese]
            segments = CppjiebaRb.segment(match_data.to_s, mode: :mix)

            if ts_config != 'english'
              segments = CppjiebaRb.filter_stop_word(segments)
            end

            segments = segments.filter { |s| s.present? }
            segmented_data << segments.join(' ')
          else
            segmented_data << match_data.to_s.squish
          end
        end

        data = segmented_data.join(' ')
      elsif segment_japanese?
        data.gsub!(japanese_punctuation_regexp, " ")
        data = TinyJapaneseSegmenter.segment(data)
        data = data.filter { |s| s.present? }
        data = data.join(' ')
      else
        data.squish!
      end

      if SiteSetting.search_ignore_accents
        data = strip_diacritics(data)
      end
    end

    data.gsub!(/\S+/) do |str|
      if str =~ /^["]?((https?:\/\/)[\S]+)["]?$/
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
    Discourse.cache.fetch("search-min-post-id:#{SiteSetting.search_recent_posts_size}", expires_in: 1.week) do
      min_post_id_no_cache
    end
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

    term = term.to_s.dup

    # Removes any zero-width characters from search terms
    term.gsub!(/[\u200B-\u200D\uFEFF]/, '')
    # Replace curly quotes to regular quotes
    term.gsub!(/[\u201c\u201d]/, '"')

    @clean_term = term
    @in_title = false

    term = process_advanced_search!(term)

    if term.present?
      @term = Search.prepare_data(term, Topic === @search_context ? :topic : nil)
      @original_term = Search.escape_string(@term)
    end

    if @search_pms || @search_all_pms || @opts[:type_filter] == 'private_messages'
      @opts[:type_filter] = "private_messages"
      @search_context ||= @guardian.user

      unless @search_context.present? && @guardian.can_see_private_messages?(@search_context.id)
        raise Discourse::InvalidAccess.new
      end
    end

    if @search_all_topics && @guardian.user
      @opts[:type_filter] = "all_topics"
    end

    @results = GroupedSearchResults.new(
      type_filter: @opts[:type_filter],
      term: clean_term,
      blurb_term: term,
      search_context: @search_context,
      blurb_length: @blurb_length
    )
  end

  def limit
    if @opts[:type_filter].present? && @opts[:type_filter] != "exclude_topics"
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
  def execute(readonly_mode: Discourse.readonly_mode?)
    if log_query?(readonly_mode)
      status, search_log_id = SearchLog.log(
        term: @clean_term,
        search_type: @opts[:search_type],
        ip_address: @opts[:ip_address],
        user_id: @opts[:user_id]
      )
      @results.search_log_id = search_log_id unless status == :error
    end

    unless @filters.present? || @opts[:search_for_id]
      min_length = min_search_term_length
      terms = (@term || '').split(/\s(?=(?:[^"]|"[^"]*")*$)/).reject { |t| t.length < min_length }

      if terms.blank?
        @term = ''
        @valid = false
        return
      end
    end

    # If the term is a number or url to a topic, just include that topic
    if @opts[:search_for_id] && ['topic', 'private_messages', 'all_topics'].include?(@results.type_filter)
      if @term =~ /^\d+$/
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
    (@advanced_orders ||= {})[trigger] = block
  end

  def self.advanced_orders
    @advanced_orders
  end

  def self.advanced_filter(trigger, &block)
    (@advanced_filters ||= {})[trigger] = block
  end

  def self.advanced_filters
    @advanced_filters
  end

  def self.custom_topic_eager_load(tables = nil, &block)
    (@custom_topic_eager_loads ||= []) << (tables || block)
  end

  def self.custom_topic_eager_loads
    Array.wrap(@custom_topic_eager_loads)
  end

  advanced_filter(/^in:personal-direct$/i) do |posts|
    if @guardian.user
      posts
        .joins("LEFT JOIN topic_allowed_groups tg ON posts.topic_id = tg.topic_id")
        .where(<<~SQL, user_id: @guardian.user.id)
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
    end
  end

  advanced_filter(/^in:all-pms$/i) do |posts|
    posts.private_posts if @guardian.is_admin?
  end

  advanced_filter(/^in:tagged$/i) do |posts|
    posts
      .where('EXISTS (SELECT 1 FROM topic_tags WHERE topic_tags.topic_id = posts.topic_id)')
  end

  advanced_filter(/^in:untagged$/i) do |posts|
    posts
      .joins("LEFT JOIN topic_tags ON
        topic_tags.topic_id = posts.topic_id")
      .where("topic_tags.id IS NULL")
  end

  advanced_filter(/^status:open$/i) do |posts|
    posts.where('NOT topics.closed AND NOT topics.archived')
  end

  advanced_filter(/^status:closed$/i) do |posts|
    posts.where('topics.closed')
  end

  advanced_filter(/^status:public$/i) do |posts|
    category_ids = Category
      .where(read_restricted: false)
      .pluck(:id)

    posts.where("topics.category_id in (?)", category_ids)
  end

  advanced_filter(/^status:archived$/i) do |posts|
    posts.where('topics.archived')
  end

  advanced_filter(/^status:noreplies$/i) do |posts|
    posts.where("topics.posts_count = 1")
  end

  advanced_filter(/^status:single_user$/i) do |posts|
    posts.where("topics.participant_count = 1")
  end

  advanced_filter(/^posts_count:(\d+)$/i) do |posts, match|
    posts.where("topics.posts_count = ?", match.to_i)
  end

  advanced_filter(/^min_post_count:(\d+)$/i) do |posts, match|
    posts.where("topics.posts_count >= ?", match.to_i)
  end

  advanced_filter(/^min_posts:(\d+)$/i) do |posts, match|
    posts.where("topics.posts_count >= ?", match.to_i)
  end

  advanced_filter(/^max_posts:(\d+)$/i) do |posts, match|
    posts.where("topics.posts_count <= ?", match.to_i)
  end

  advanced_filter(/^in:first|^f$/i) do |posts|
    posts.where("posts.post_number = 1")
  end

  advanced_filter(/^in:pinned$/i) do |posts|
    posts.where("topics.pinned_at IS NOT NULL")
  end

  advanced_filter(/^in:wiki$/i) do |posts, match|
    posts.where(wiki: true)
  end

  advanced_filter(/^badge:(.*)$/i) do |posts, match|
    badge_id = Badge.where('name ilike ? OR id = ?', match, match.to_i).pluck_first(:id)
    if badge_id
      posts.where('posts.user_id IN (SELECT ub.user_id FROM user_badges ub WHERE ub.badge_id = ?)', badge_id)
    else
      posts.where("1 = 0")
    end
  end

  def post_action_type_filter(posts, post_action_type)
    posts.where("posts.id IN (
      SELECT pa.post_id FROM post_actions pa
      WHERE pa.user_id = #{@guardian.user.id} AND
            pa.post_action_type_id = #{post_action_type} AND
            deleted_at IS NULL
    )")
  end

  advanced_filter(/^in:(likes)$/i) do |posts, match|
    if @guardian.user
      post_action_type_filter(posts, PostActionType.types[:like])
    end
  end

  advanced_filter(/^in:(bookmarks)$/i) do |posts, match|
    if @guardian.user
      posts.where("posts.id IN (SELECT post_id FROM bookmarks WHERE bookmarks.user_id = #{@guardian.user.id})")
    end
  end

  advanced_filter(/^in:posted$/i) do |posts|
    posts.where("posts.user_id = #{@guardian.user.id}") if @guardian.user
  end

  advanced_filter(/^in:(created|mine)$/i) do |posts|
    posts.where(user_id: @guardian.user.id, post_number: 1) if @guardian.user
  end

  advanced_filter(/^created:@(.*)$/i) do |posts, match|
    user_id = User.where(username: match.downcase).pluck_first(:id)
    posts.where(user_id: user_id, post_number: 1)
  end

  advanced_filter(/^in:(watching|tracking)$/i) do |posts, match|
    if @guardian.user
      level = TopicUser.notification_levels[match.downcase.to_sym]
      posts.where("posts.topic_id IN (
                    SELECT tu.topic_id FROM topic_users tu
                    WHERE tu.user_id = :user_id AND
                          tu.notification_level >= :level
                   )", user_id: @guardian.user.id, level: level)

    end
  end

  advanced_filter(/^in:seen$/i) do |posts|
    if @guardian.user
      posts
        .joins("INNER JOIN post_timings ON
          post_timings.topic_id = posts.topic_id
          AND post_timings.post_number = posts.post_number
          AND post_timings.user_id = #{ActiveRecord::Base.connection.quote(@guardian.user.id)}
        ")
    end
  end

  advanced_filter(/^in:unseen$/i) do |posts|
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

  advanced_filter(/^with:images$/i) do |posts|
    posts.where("posts.image_upload_id IS NOT NULL")
  end

  advanced_filter(/^category:(.+)$/i) do |posts, match|
    exact = false

    if match[0] == "="
      exact = true
      match = match[1..-1]
    end

    category_ids = Category.where('slug ilike ? OR name ilike ? OR id = ?',
                                  match, match, match.to_i).pluck(:id)
    if category_ids.present?
      category_ids += Category.subcategory_ids(category_ids.first) unless exact
      @category_filter_matched ||= true
      posts.where("topics.category_id IN (?)", category_ids)
    else
      posts.where("1 = 0")
    end
  end

  advanced_filter(/^\#([\p{L}\p{M}0-9\-:=]+)$/i) do |posts, match|
    category_slug, subcategory_slug = match.to_s.split(":")
    next unless category_slug

    exact = true
    if category_slug[0] == "="
      category_slug = category_slug[1..-1]
    else
      exact = false
    end

    category_id = if subcategory_slug
      Category
        .where('lower(slug) = ?', subcategory_slug.downcase)
        .where(parent_category_id: Category.where('lower(slug) = ?', category_slug.downcase).select(:id))
        .pluck_first(:id)
    else
      Category
        .where('lower(slug) = ?', category_slug.downcase)
        .order('case when parent_category_id is null then 0 else 1 end')
        .pluck_first(:id)
    end

    if category_id
      category_ids = [category_id]
      category_ids += Category.subcategory_ids(category_id) if !exact

      @category_filter_matched ||= true
      posts.where("topics.category_id IN (?)", category_ids)
    else
      # try a possible tag match
      tag_id = Tag.where_name(category_slug).pluck_first(:id)
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

  advanced_filter(/^group:(.+)$/i) do |posts, match|
    group_id = Group
      .visible_groups(@guardian.user)
      .members_visible_groups(@guardian.user)
      .where('name ilike ? OR (id = ? AND id > 0)', match, match.to_i).pluck_first(:id)

    if group_id
      posts.where("posts.user_id IN (select gu.user_id from group_users gu where gu.group_id = ?)", group_id)
    else
      posts.where("1 = 0")
    end
  end

  advanced_filter(/^user:(.+)$/i) do |posts, match|
    user_id = User.where(staged: false).where('username_lower = ? OR id = ?', match.downcase, match.to_i).pluck_first(:id)
    if user_id
      posts.where("posts.user_id = #{user_id}")
    else
      posts.where("1 = 0")
    end
  end

  advanced_filter(/^\@([a-zA-Z0-9_\-.]+)$/i) do |posts, match|
    username = match.downcase

    user_id = User.where(staged: false).where(username_lower: username).pluck_first(:id)

    if !user_id && username == "me"
      user_id = @guardian.user&.id
    end

    if user_id
      posts.where("posts.user_id = #{user_id}")
    else
      posts.where("1 = 0")
    end
  end

  advanced_filter(/^before:(.*)$/i) do |posts, match|
    if date = Search.word_to_date(match)
      posts.where("posts.created_at < ?", date)
    else
      posts
    end
  end

  advanced_filter(/^after:(.*)$/i) do |posts, match|
    if date = Search.word_to_date(match)
      posts.where("posts.created_at > ?", date)
    else
      posts
    end
  end

  advanced_filter(/^tags?:([\p{L}\p{M}0-9,\-_+]+)$/i) do |posts, match|
    search_tags(posts, match, positive: true)
  end

  advanced_filter(/^\-tags?:([\p{L}\p{M}0-9,\-_+]+)$/i) do |posts, match|
    search_tags(posts, match, positive: false)
  end

  advanced_filter(/^filetypes?:([a-zA-Z0-9,\-_]+)$/i) do |posts, match|
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

  advanced_filter(/^min_views:(\d+)$/i) do |posts, match|
    posts.where("topics.views >= ?", match.to_i)
  end

  advanced_filter(/^max_views:(\d+)$/i) do |posts, match|
    posts.where("topics.views <= ?", match.to_i)
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

      if word == 'l'
        @order = :latest
        nil
      elsif word =~ /^order:\w+$/i
        @order = word.downcase.gsub('order:', '').to_sym
        nil
      elsif word =~ /^in:title$/i || word == 't'
        @in_title = true
        nil
      elsif word =~ /^topic:(\d+)$/i
        topic_id = $1.to_i
        if topic_id > 1
          topic = Topic.find_by(id: topic_id)
          if @guardian.can_see?(topic)
            @search_context = topic
          end
        end
        nil
      elsif word =~ /^in:all$/i
        @search_all_topics = true
        nil
      elsif word =~ /^in:personal$/i
        @search_pms = true
        nil
      elsif word =~ /^in:personal-direct$/i
        @search_pms = true
        nil
      elsif word =~ /^in:all-pms$/i
        @search_all_pms = true
        nil
      elsif word =~ /^personal_messages:(.+)$/i
        if user = User.find_by_username($1)
          @search_pms = true
          @search_context = user
        end

        nil
      else
        found ? nil : word
      end
    end.compact.join(' ')
  end

  def find_grouped_results
    if @results.type_filter.present?
      raise Discourse::InvalidAccess.new("invalid type filter") unless Search.facets.include?(@results.type_filter)
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
      archetype = @opts[:restrict_to_archetype] == Archetype.default ? Archetype.default : Archetype.private_message

      post = posts_scope
        .joins(:topic)
        .find_by(
          "topics.id = :id AND topics.archetype = :archetype AND posts.post_number = 1",
          id: id,
          archetype: archetype
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

    users = User
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

    users_custom_data_query = DB.query(<<~SQL, user_ids: users.pluck(:id), term: "%#{@original_term.downcase}%")
      SELECT user_custom_fields.user_id, user_fields.name, user_custom_fields.value FROM user_custom_fields
      INNER JOIN user_fields ON user_fields.id = REPLACE(user_custom_fields.name, 'user_field_', '')::INTEGER AND user_fields.searchable IS TRUE
      WHERE user_id IN (:user_ids)
      AND user_custom_fields.name LIKE 'user_field_%'
      AND user_custom_fields.value ILIKE :term
    SQL
    users_custom_data = users_custom_data_query.reduce({}) do |acc, row|
      acc[row.user_id] =
        Array.wrap(acc[row.user_id]) << {
          name: row.name,
          value: row.value
        }
      acc
    end

    users.each do |user|
      user.custom_data = users_custom_data[user.id] || []
      @results.add(user)
    end
  end

  def groups_search
    groups = Group
      .visible_groups(@guardian.user, "name ASC", include_everyone: false)
      .where("name ILIKE :term OR full_name ILIKE :term", term: "%#{@term}%")
      .limit(limit)

    groups.each { |group| @results.add(group) }
  end

  def tags_search
    return unless SiteSetting.tagging_enabled
    tags = Tag.includes(:tag_search_data)
      .where("tag_search_data.search_data @@ #{ts_query}")
      .references(:tag_search_data)
      .order("name asc")
      .limit(limit)

    hidden_tag_names = DiscourseTagging.hidden_tag_names(@guardian)

    tags.each do |tag|
      @results.add(tag) if !hidden_tag_names.include?(tag.name)
    end
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
    posts = Post.where(post_type: Topic.visible_post_types(@guardian.user))
      .joins(:post_search_data, :topic)

    if type_filter != "private_messages"
      posts = posts.joins("LEFT JOIN categories ON categories.id = topics.category_id")
    end

    is_topic_search = @search_context.present? && @search_context.is_a?(Topic)
    posts = posts.where("topics.visible") unless is_topic_search

    if type_filter == "private_messages" || (is_topic_search && @search_context.private_message?)
      posts = posts
        .where(
          "topics.archetype = ? AND post_search_data.private_message",
          Archetype.private_message
        )

      unless @guardian.is_admin?
        posts = posts.private_posts_for_user(@guardian.user)
      end
    elsif type_filter == "all_topics"
      private_posts = posts
        .where(
          "topics.archetype = ? AND post_search_data.private_message",
          Archetype.private_message
          )
        .private_posts_for_user(@guardian.user)

      posts = posts
        .where(
          "topics.archetype <> ? AND NOT post_search_data.private_message",
          Archetype.private_message
        )
        .or(private_posts)
    else
      posts = posts.where(
        "topics.archetype <> ? AND NOT post_search_data.private_message",
        Archetype.private_message
      )
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
        posts = posts.where(post_number: 1) if @in_title
        posts = posts.where("post_search_data.search_data @@ #{ts_query(weight_filter: weights)}")
        exact_terms = @term.scan(Regexp.new(PHRASE_MATCH_REGEXP_PATTERN)).flatten

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
          category_ids = Category
            .where(parent_category_id: @search_context.id)
            .pluck(:id)
            .push(@search_context.id)

          posts.where("topics.category_id in (?)", category_ids)
        elsif is_topic_search
          posts.where("topics.id = #{@search_context.id}")
            .order("posts.post_number #{@order == :latest ? "DESC" : ""}")
        elsif @search_context.is_a?(Tag)
          posts = posts
            .joins("LEFT JOIN topic_tags ON topic_tags.topic_id = topics.id")
            .joins("LEFT JOIN tags ON tags.id = topic_tags.tag_id")
          posts.where("tags.id = #{@search_context.id}")
        end
      else
        posts = categories_ignored(posts) unless @category_filter_matched
        posts
      end

    if @order == :latest
      if aggregate_search
        posts = posts.order("MAX(posts.created_at) DESC")
      else
        posts = posts.reorder("posts.created_at DESC")
      end
    elsif @order == :latest_topic
      if aggregate_search
        posts = posts.order("MAX(topics.created_at) DESC")
      else
        posts = posts.order("topics.created_at DESC")
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
    elsif !is_topic_search
      rank = <<~SQL
      TS_RANK_CD(
        post_search_data.search_data,
        #{@term.blank? ? '' : ts_query(weight_filter: weights)},
        #{SiteSetting.search_ranking_normalization}|32
      )
      SQL

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

        category_priority_weights = <<~SQL
        (
          CASE categories.search_priority
          WHEN #{Searchable::PRIORITIES[:low]}
          THEN #{SiteSetting.category_search_priority_low_weight}
          WHEN #{Searchable::PRIORITIES[:high]}
          THEN #{SiteSetting.category_search_priority_high_weight}
          ELSE
            CASE WHEN topics.closed
            THEN 0.9
            ELSE 1
            END
          END
        )
        SQL

        data_ranking =
          if @term.blank?
            "(#{category_priority_weights})"
          else
            "(#{rank} * #{category_priority_weights})"
          end

        posts =
          if aggregate_search
            posts.order("MAX(#{category_search_priority}) DESC", "MAX(#{data_ranking}) DESC")
          else
            posts.order("#{category_search_priority} DESC", "#{data_ranking} DESC")
          end
      end

      posts = posts.order("topics.bumped_at DESC")
    end

    if type_filter != "private_messages"
      posts =
        if secure_category_ids.present?
          posts.where("(categories.id IS NULL) OR (NOT categories.read_restricted) OR (categories.id IN (?))", secure_category_ids).references(:categories)
        else
          posts.where("(categories.id IS NULL) OR (NOT categories.read_restricted)").references(:categories)
        end
    end

    if @order
      advanced_order = Search.advanced_orders&.fetch(@order, nil)
      posts = advanced_order.call(posts) if advanced_order
    end

    posts = posts.offset(offset)
    posts.limit(limit)
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

  def self.ts_query(term: , ts_config:  nil, joiner: nil, weight_filter: nil)
    to_tsquery(
      ts_config: ts_config,
      term: set_tsquery_weight_filter(term, weight_filter),
      joiner: joiner
    )
  end

  def self.to_tsquery(ts_config: nil, term:, joiner: nil)
    ts_config = ActiveRecord::Base.connection.quote(ts_config) if ts_config
    tsquery = "TO_TSQUERY(#{ts_config || default_ts_config}, '#{self.escape_string(term)}')"
    tsquery = "REPLACE(#{tsquery}::text, '&', '#{self.escape_string(joiner)}')::tsquery" if joiner
    tsquery
  end

  def self.set_tsquery_weight_filter(term, weight_filter)
    "'#{self.escape_string(term)}':*#{weight_filter}"
  end

  def self.escape_string(term)
    PG::Connection.escape_string(term).gsub('\\', '\\\\\\')
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
    default_opts = {
      type_filter: opts[:type_filter]
    }

    min_id =
      if SiteSetting.search_recent_regular_posts_offset_post_id > 0
        if %w{all_topics private_message}.include?(opts[:type_filter])
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
        posts_query(limit, type_filter: opts[:type_filter])
          .select('topics.id', "posts.post_number")
      else
        posts_query(limit, aggregate_search: true, type_filter: opts[:type_filter])
          .select('topics.id', "#{min_or_max}(posts.post_number) post_number")
          .group('topics.id')
      end

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

    posts_scope(posts_eager_loads(Post))
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

    aggregate_search(type_filter: "private_messages")
  end

  def all_topics_search
    aggregate_search(type_filter: "all_topics")
  end

  def topic_search
    if @search_context.is_a?(Topic)
      posts = posts_scope(posts_eager_loads(posts_query(limit)))
        .where('posts.topic_id = ?', @search_context.id)

      posts.each do |post|
        @results.add(post)
      end
    else
      aggregate_search
    end
  end

  def posts_eager_loads(query)
    query = query.includes(:user, :post_search_data)
    topic_eager_loads = [:category]

    if SiteSetting.tagging_enabled
      topic_eager_loads << :tags
    end

    Search.custom_topic_eager_loads.each do |custom_loads|
      topic_eager_loads.concat(custom_loads.is_a?(Array) ? custom_loads : custom_loads.call(search_pms: @search_pms).to_a)
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
          default_scope.arel.projections
        )
    else
      default_scope
    end
  end

  def log_query?(readonly_mode)
    SiteSetting.log_search_queries? &&
    @opts[:search_type].present? &&
    !readonly_mode &&
    @opts[:type_filter] != "exclude_topics"
  end

  def min_search_term_length
    return @opts[:min_search_term_length] if @opts[:min_search_term_length]

    if SiteSetting.search_tokenize_chinese
      return SiteSetting.defaults.get('min_search_term_length', 'zh_CN')
    end

    if SiteSetting.search_tokenize_japanese
      return SiteSetting.defaults.get('min_search_term_length', 'ja')
    end

    SiteSetting.min_search_term_length
  end
end
