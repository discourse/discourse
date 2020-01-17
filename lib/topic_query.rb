# frozen_string_literal: true

#
# Helps us find topics.
# Returns a TopicList object containing the topics found.
#

class TopicQuery
  PG_MAX_INT ||= 2147483647

  def self.validators
    @validators ||= begin

      int = lambda do |x|
        Integer === x || (String === x && x.match?(/^-?[0-9]+$/))
      end

      zero_up_to_max_int = lambda do |x|
        int.call(x) && x.to_i.between?(0, PG_MAX_INT)
      end

      array_int_or_int = lambda do |x|
        int.call(x) || (
          Array === x && x.length > 0 && x.all?(&int)
        )
      end

      {
        max_posts: zero_up_to_max_int,
        min_posts: zero_up_to_max_int,
        page: zero_up_to_max_int
      }
    end
  end

  def self.validate?(option, value)

    if fn = validators[option.to_sym]
      fn.call(value)
    else
      true
    end
  end

  def self.public_valid_options
    @public_valid_options ||=
      %i(page
         before
         bumped_before
         topic_ids
         category
         order
         ascending
         min_posts
         max_posts
         status
         filter
         state
         search
         q
         group_name
         tags
         match_all_tags
         no_subcategories
         no_tags)
  end

  def self.valid_options
    @valid_options ||=
      public_valid_options +
      %i(except_topic_ids
         limit
         page
         per_page
         visible
         guardian
         no_definitions
         destination_category_id)
  end

  # Maps `order` to a columns in `topics`
  SORTABLE_MAPPING = {
    'likes' => 'like_count',
    'op_likes' => 'op_likes',
    'views' => 'views',
    'posts' => 'posts_count',
    'activity' => 'bumped_at',
    'posters' => 'participant_count',
    'category' => 'category_id',
    'created' => 'created_at'
  }

  cattr_accessor :results_filter_callbacks
  self.results_filter_callbacks = []

  attr_accessor :options, :user, :guardian

  def self.add_custom_filter(key, &blk)
    @custom_filters ||= {}
    valid_options << key
    public_valid_options << key
    @custom_filters[key] = blk
  end

  def self.remove_custom_filter(key)
    @custom_filters.delete(key)
    public_valid_options.delete(key)
    valid_options.delete(key)
    @custom_filters = nil if @custom_filters.length == 0
  end

  def self.apply_custom_filters(results, topic_query)
    if @custom_filters
      @custom_filters.each do |key, filter|
        results = filter.call(results, topic_query)
      end
    end
    results
  end

  def initialize(user = nil, options = {})
    options.assert_valid_keys(TopicQuery.valid_options)
    @options = options.dup
    @user = user
    @guardian = options[:guardian] || Guardian.new(@user)
  end

  def joined_topic_user(list = nil)
    (list || Topic).joins("LEFT OUTER JOIN topic_users AS tu ON (topics.id = tu.topic_id AND tu.user_id = #{@user.id.to_i})")
  end

  def get_pm_params(topic)
    if topic.private_message?

      my_group_ids = topic.topic_allowed_groups
        .joins("
          LEFT JOIN group_users gu
          ON topic_allowed_groups.group_id = gu.group_id
          AND gu.user_id = #{@user.id.to_i}
        ")
        .where("gu.group_id IS NOT NULL")
        .pluck(:group_id)

      target_group_ids = topic.topic_allowed_groups.pluck(:group_id)

      target_users = topic
        .topic_allowed_users

      if my_group_ids.present?

        # strip out users in groups you already belong to
        target_users = target_users
          .joins("LEFT JOIN group_users gu ON gu.user_id = topic_allowed_users.user_id AND gu.group_id IN (#{sanitize_sql_array(my_group_ids)})")
          .where('gu.group_id IS NULL')
      end

      target_user_ids = target_users
        .where('NOT topic_allowed_users.user_id = ?', @user.id)
        .pluck(:user_id)

      {
        topic: topic,
        my_group_ids: my_group_ids,
        target_group_ids: target_group_ids,
        target_user_ids: target_user_ids
      }
    end
  end

  def list_related_for(topic, pm_params: nil)
    return if !topic.private_message?
    return if @user.blank?
    return if !SiteSetting.enable_personal_messages?

    builder = SuggestedTopicsBuilder.new(topic)
    pm_params = pm_params || get_pm_params(topic)

    if pm_params[:my_group_ids].present?
      builder.add_results(related_messages_group(
        pm_params.merge(count: [6, builder.results_left].max,
                        exclude: builder.excluded_topic_ids)
      ))
    else
      builder.add_results(related_messages_user(
        pm_params.merge(count: [6, builder.results_left].max,
                        exclude: builder.excluded_topic_ids)
      ))
    end

    params = { unordered: true }
    params[:preload_posters] = true
    create_list(:suggested, params, builder.results)
  end

  # Return a list of suggested topics for a topic
  def list_suggested_for(topic, pm_params: nil)

    # Don't suggest messages unless we have a user, and private messages are
    # enabled.
    return if topic.private_message? &&
      (@user.blank? || !SiteSetting.enable_personal_messages?)

    builder = SuggestedTopicsBuilder.new(topic)

    pm_params = pm_params || get_pm_params(topic)

    # When logged in we start with different results
    if @user
      if topic.private_message?

        builder.add_results(new_messages(
          pm_params.merge(count: builder.results_left)
        )) unless builder.full?

        builder.add_results(unread_messages(
          pm_params.merge(count: builder.results_left)
        )) unless builder.full?

      else

        builder.add_results(
          unread_results(
            topic: topic,
            per_page: builder.results_left,
            max_age: SiteSetting.suggested_topics_unread_max_days_old
          ), :high
        )

        builder.add_results(new_results(topic: topic, per_page: builder.category_results_left)) unless builder.full?
      end
    end

    if !topic.private_message?
      builder.add_results(random_suggested(topic, builder.results_left, builder.excluded_topic_ids)) unless builder.full?
    end

    params = { unordered: true }
    if topic.private_message?
      params[:preload_posters] = true
    end
    create_list(:suggested, params, builder.results)
  end

  # The latest view of topics
  def list_latest
    create_list(:latest, {}, latest_results)
  end

  def list_read
    create_list(:read, unordered: true) do |topics|
      topics.where('tu.last_visited_at IS NOT NULL').order('tu.last_visited_at DESC')
    end
  end

  def list_new
    create_list(:new, { unordered: true }, new_results)
  end

  def list_unread
    create_list(:unread, { unordered: true }, unread_results)
  end

  def list_posted
    create_list(:posted) { |l| l.where('tu.posted') }
  end

  def list_bookmarks
    create_list(:bookmarks) { |l| l.where('tu.bookmarked') }
  end

  def list_top_for(period)
    score = "#{period}_score"
    create_list(:top, unordered: true) do |topics|
      topics = topics.joins(:top_topic).where("top_topics.#{score} > 0")
      if period == :yearly && @user.try(:trust_level) == TrustLevel[0]
        topics.order(TopicQuerySQL.order_top_with_pinned_category_for(score))
      else
        topics.order(TopicQuerySQL.order_top_for(score))
      end
    end
  end

  def list_topics_by(user)
    @options[:filtered_to_user] = user.id
    create_list(:user_topics) do |topics|
      topics.where(user_id: user.id)
    end
  end

  def not_archived(list, user)
    list.joins("LEFT JOIN user_archived_messages um
                       ON um.user_id = #{user.id.to_i} AND um.topic_id = topics.id")
      .where('um.user_id IS NULL')
  end

  def list_group_topics(group)
    list = default_results.where("
      topics.user_id IN (
        SELECT user_id FROM group_users gu WHERE gu.group_id = #{group.id.to_i}
      )
    ")

    create_list(:group_topics, {}, list)
  end

  def list_private_messages(user)
    list = private_messages_for(user, :user)

    list = not_archived(list, user)
      .where('NOT (topics.participant_count = 1 AND topics.user_id = ? AND topics.moderator_posts_count = 0)', user.id)

    create_list(:private_messages, {}, list)
  end

  def list_private_messages_archive(user)
    list = private_messages_for(user, :user)
    list = list.joins(:user_archived_messages).where('user_archived_messages.user_id = ?', user.id)
    create_list(:private_messages, {}, list)
  end

  def list_private_messages_sent(user)
    list = private_messages_for(user, :user)
    list = list.where('EXISTS (
                      SELECT 1 FROM posts
                      WHERE posts.topic_id = topics.id AND
                            posts.user_id = ?
                     )', user.id)
    list = not_archived(list, user)
    create_list(:private_messages, {}, list)
  end

  def list_private_messages_unread(user)
    list = private_messages_for(user, :user)
    list = list.where("tu.last_read_post_number IS NULL OR tu.last_read_post_number < topics.highest_post_number")
    create_list(:private_messages, {}, list)
  end

  def list_private_messages_group(user)
    list = private_messages_for(user, :group)
    group = Group.where('name ilike ?', @options[:group_name]).select(:id, :publish_read_state).first
    publish_read_state = !!group&.publish_read_state
    list = list.joins("LEFT JOIN group_archived_messages gm ON gm.topic_id = topics.id AND
                      gm.group_id = #{group&.id&.to_i}")
    list = list.where("gm.id IS NULL")
    list = append_read_state(list, group) if publish_read_state
    create_list(:private_messages, { publish_read_state: publish_read_state }, list)
  end

  def list_private_messages_group_archive(user)
    list = private_messages_for(user, :group)
    group_id = Group.where('name ilike ?', @options[:group_name]).pluck_first(:id)
    list = list.joins("JOIN group_archived_messages gm ON gm.topic_id = topics.id AND
                      gm.group_id = #{group_id.to_i}")
    create_list(:private_messages, {}, list)
  end

  def list_private_messages_tag(user)
    list = private_messages_for(user, :all)
    list = list.joins("JOIN topic_tags tt ON tt.topic_id = topics.id
                      JOIN tags t ON t.id = tt.tag_id AND t.name = '#{@options[:tags][0]}'")
    create_list(:private_messages, {}, list)
  end

  def list_category_topic_ids(category)
    query = default_results(category: category.id)
    pinned_ids = query.where('topics.pinned_at IS NOT NULL AND topics.category_id = ?', category.id).limit(nil).order('pinned_at DESC').pluck(:id)
    non_pinned_ids = query.where('topics.pinned_at IS NULL OR topics.category_id <> ?', category.id).pluck(:id)
    (pinned_ids + non_pinned_ids)
  end

  def list_new_in_category(category)
    create_list(:new_in_category, unordered: true, category: category.id) do |list|
      list.by_newest.first(25)
    end
  end

  def self.new_filter(list, treat_as_new_topic_start_date)
    list.where("topics.created_at >= :created_at", created_at: treat_as_new_topic_start_date)
      .where("tu.last_read_post_number IS NULL")
      .where("COALESCE(tu.notification_level, :tracking) >= :tracking", tracking: TopicUser.notification_levels[:tracking])
  end

  def self.unread_filter(list, user_id, opts)
    col_name = opts[:staff] ? "highest_staff_post_number" : "highest_post_number"

    list
      .where("tu.last_read_post_number < topics.#{col_name}")
      .where("COALESCE(tu.notification_level, :regular) >= :tracking",
               regular: TopicUser.notification_levels[:regular], tracking: TopicUser.notification_levels[:tracking])
  end

  def prioritize_pinned_topics(topics, options)
    pinned_clause = if options[:category_id]
      +"topics.category_id = #{options[:category_id].to_i} AND"
    else
      +"pinned_globally AND "
    end

    pinned_clause << " pinned_at IS NOT NULL "

    if @user
      pinned_clause << " AND (topics.pinned_at > tu.cleared_pinned_at OR tu.cleared_pinned_at IS NULL)"
    end

    unpinned_topics = topics.where("NOT ( #{pinned_clause} )")
    pinned_topics = topics.dup.offset(nil).where(pinned_clause)

    per_page = options[:per_page] || per_page_setting
    limit = per_page unless options[:limit] == false
    page = options[:page].to_i

    if page == 0
      (pinned_topics + unpinned_topics)[0...limit] if limit
    else
      offset = (page * per_page) - pinned_topics.length
      offset = 0 unless offset > 0
      unpinned_topics.offset(offset).to_a
    end

  end

  def create_list(filter, options = {}, topics = nil)
    topics ||= default_results(options)
    topics = yield(topics) if block_given?

    options = options.merge(@options)
    if ["activity", "default"].include?(options[:order] || "activity") &&
        !options[:unordered] &&
        filter != :private_messages
      topics = prioritize_pinned_topics(topics, options)
    end

    topics = topics.to_a

    if options[:preload_posters]
      user_ids = []
      topics.each do |ft|
        user_ids << ft.user_id << ft.last_post_user_id << ft.featured_user_ids << ft.allowed_user_ids
      end

      avatar_lookup = AvatarLookup.new(user_ids)
      primary_group_lookup = PrimaryGroupLookup.new(user_ids)

      # memoize for loop so we don't keep looking these up
      translations = TopicPostersSummary.translations

      topics.each do |t|
        t.posters = t.posters_summary(
          avatar_lookup: avatar_lookup,
          primary_group_lookup: primary_group_lookup,
          translations: translations
        )
      end
    end

    topics.each do |t|
      t.allowed_user_ids = filter == :private_messages ? t.allowed_users.map { |u| u.id } : []
    end

    list = TopicList.new(filter, @user, topics, options.merge(@options))
    list.per_page = options[:per_page] || per_page_setting
    list
  end

  def latest_results(options = {})
    result = default_results(options)
    result = remove_muted_topics(result, @user) unless options && options[:state] == "muted".freeze
    result = remove_muted_categories(result, @user, exclude: options[:category])
    result = remove_muted_tags(result, @user, options)
    result = apply_shared_drafts(result, get_category_id(options[:category]), options)

    # plugins can remove topics here:
    self.class.results_filter_callbacks.each do |filter_callback|
      result = filter_callback.call(:latest, result, @user, options)
    end

    result
  end

  def unread_results(options = {})
    result = TopicQuery.unread_filter(
        default_results(options.reverse_merge(unordered: true)),
        @user&.id,
        staff: @user&.staff?)
      .order('CASE WHEN topics.user_id = tu.user_id THEN 1 ELSE 2 END')

    if @user
      # micro optimisation so we don't load up all of user stats which we do not need
      unread_at = DB.query_single(
        "select first_unread_at from user_stats where user_id = ?",
        @user.id).first

      if max_age = options[:max_age]
        max_age_date = max_age.days.ago
        unread_at ||= max_age_date
        unread_at = unread_at > max_age_date ? unread_at : max_age_date
      end

      # perf note, in the past we tried doing this in a subquery but performance was
      # terrible, also tried with a join and it was bad
      result = result.where("topics.updated_at >= ?", unread_at)
    end

    self.class.results_filter_callbacks.each do |filter_callback|
      result = filter_callback.call(:unread, result, @user, options)
    end

    suggested_ordering(result, options)
  end

  def new_results(options = {})
    # TODO does this make sense or should it be ordered on created_at
    #  it is ordering on bumped_at now
    result = TopicQuery.new_filter(default_results(options.reverse_merge(unordered: true)), @user.user_option.treat_as_new_topic_start_date)
    result = remove_muted_topics(result, @user)
    result = remove_muted_categories(result, @user, exclude: options[:category])
    result = remove_muted_tags(result, @user, options)
    result = remove_already_seen_for_category(result, @user)

    self.class.results_filter_callbacks.each do |filter_callback|
      result = filter_callback.call(:new, result, @user, options)
    end

    suggested_ordering(result, options)
  end

  protected

  def per_page_setting
    30
  end

  def private_messages_for(user, type)
    options = @options
    options.reverse_merge!(per_page: per_page_setting)

    result = Topic.includes(:tags)

    if type == :group
      result = result.includes(:allowed_users)
      result = result.where("
        topics.id IN (
          SELECT topic_id FROM topic_allowed_groups
          WHERE (
            group_id IN (
              SELECT group_id
              FROM group_users
              WHERE user_id = #{user.id.to_i}
              OR #{user.staff?}
            )
          )
          AND group_id IN (SELECT id FROM groups WHERE name ilike ?)
        )",
        @options[:group_name]
      )
    elsif type == :user
      result = result.includes(:allowed_users)
      result = result.where("topics.id IN (SELECT topic_id FROM topic_allowed_users WHERE user_id = #{user.id.to_i})")
    elsif type == :all
      result = result.includes(:allowed_users)
      result = result.where("topics.id IN (
            SELECT topic_id
            FROM topic_allowed_users
            WHERE user_id = #{user.id.to_i}
            UNION ALL
            SELECT topic_id FROM topic_allowed_groups
            WHERE group_id IN (
              SELECT group_id FROM group_users WHERE user_id = #{user.id.to_i}
            )
    )")
    end

    result = result.joins("LEFT OUTER JOIN topic_users AS tu ON (topics.id = tu.topic_id AND tu.user_id = #{user.id.to_i})")
      .order("topics.bumped_at DESC")
      .private_messages

    result = result.limit(options[:per_page]) unless options[:limit] == false
    result = result.visible if options[:visible] || @user.nil? || @user.regular?

    if options[:page]
      offset = options[:page].to_i * options[:per_page]
      result = result.offset(offset) if offset > 0
    end
    result
  end

  def apply_shared_drafts(result, category_id, options)

    # PERF: avoid any penalty if there are no shared drafts enabled
    # on some sites the cost can be high eg: gearbox
    return result if SiteSetting.shared_drafts_category == ""

    drafts_category_id = SiteSetting.shared_drafts_category.to_i
    viewing_shared = category_id && category_id == drafts_category_id
    can_create_shared = guardian.can_create_shared_draft?

    if can_create_shared && options[:destination_category_id]
      destination_category_id = get_category_id(options[:destination_category_id])
      topic_ids = SharedDraft.where(category_id: destination_category_id).pluck(:topic_id)
      result.where(id: topic_ids)
    elsif can_create_shared && viewing_shared
      result.includes(:shared_draft).references(:shared_draft)
    else
      result.where('topics.category_id != ?', drafts_category_id)
    end
  end

  def apply_ordering(result, options)
    sort_column = SORTABLE_MAPPING[options[:order]] || 'default'
    sort_dir = (options[:ascending] == "true") ? "ASC" : "DESC"

    # If we are sorting in the default order desc, we should consider including pinned
    # topics. Otherwise, just use bumped_at.
    if sort_column == 'default'
      if sort_dir == 'DESC'
        # If something requires a custom order, for example "unread" which sorts the least read
        # to the top, do nothing
        return result if options[:unordered]
      end
      sort_column = 'bumped_at'
    end

    # If we are sorting by category, actually use the name
    if sort_column == 'category_id'
      # TODO forces a table scan, slow
      return result.references(:categories).order(TopicQuerySQL.order_by_category_sql(sort_dir))
    end

    if sort_column == 'op_likes'
      return result.includes(:first_post).order("(SELECT like_count FROM posts p3 WHERE p3.topic_id = topics.id AND p3.post_number = 1) #{sort_dir}")
    end

    if sort_column.start_with?('custom_fields')
      field = sort_column.split('.')[1]
      return result.order("(SELECT CASE WHEN EXISTS (SELECT true FROM topic_custom_fields tcf WHERE tcf.topic_id::integer = topics.id::integer AND tcf.name = '#{field}') THEN (SELECT value::integer FROM topic_custom_fields tcf WHERE tcf.topic_id::integer = topics.id::integer AND tcf.name = '#{field}') ELSE 0 END) #{sort_dir}")
    end

    result.order("topics.#{sort_column} #{sort_dir}")
  end

  def get_category_id(category_id_or_slug)
    return nil unless category_id_or_slug.present?
    category_id = category_id_or_slug.to_i

    if category_id == 0
      category_id =
        Category
          .where(slug: category_id_or_slug, parent_category_id: nil)
          .pluck_first(:id)
    end

    category_id
  end

  # Create results based on a bunch of default options
  def default_results(options = {})
    options.reverse_merge!(@options)
    options.reverse_merge!(per_page: per_page_setting)

    # Whether to return visible topics
    options[:visible] = true if @user.nil? || @user.regular?
    options[:visible] = false if @user && @user.id == options[:filtered_to_user]

    # Start with a list of all topics
    result = Topic.unscoped.includes(:category)

    if @user
      result = result.joins("LEFT OUTER JOIN topic_users AS tu ON (topics.id = tu.topic_id AND tu.user_id = #{@user.id.to_i})")
        .references('tu')
    end

    category_id = get_category_id(options[:category])
    @options[:category_id] = category_id
    if category_id
      if options[:no_subcategories]
        result = result.where('categories.id = ?', category_id)
      else
        sql = <<~SQL
            categories.id IN (
              WITH RECURSIVE subcategories AS (
                SELECT :category_id id, 1 depth
                UNION
                SELECT categories.id, (subcategories.depth + 1) depth
                FROM categories
                JOIN subcategories ON subcategories.id = categories.parent_category_id
                WHERE subcategories.depth < :max_category_nesting
            )
              SELECT subcategories.id FROM subcategories
            ) AND (categories.id = :category_id OR topics.id != categories.topic_id)
          SQL
        result = result.where(sql, category_id: category_id, max_category_nesting: SiteSetting.max_category_nesting)
      end
      result = result.references(:categories)

      if !@options[:order]
        # category default sort order
        sort_order, sort_ascending = Category.where(id: category_id).pluck_first(:sort_order, :sort_ascending)
        if sort_order
          options[:order] = sort_order
          options[:ascending] = !!sort_ascending ? 'true' : 'false'
        end
      end
    end

    if SiteSetting.tagging_enabled
      result = result.preload(:tags)

      tags_arg = @options[:tags]

      if tags_arg && tags_arg.size > 0
        tags_arg = tags_arg.split if String === tags_arg

        tags_arg = tags_arg.map do |t|
          if String === t
            t.downcase
          else
            t
          end
        end

        tags_query = tags_arg[0].is_a?(String) ? Tag.where_name(tags_arg) : Tag.where(id: tags_arg)
        tags = tags_query.select(:id, :target_tag_id).map { |t| t.target_tag_id || t.id }.uniq

        if @options[:match_all_tags]
          # ALL of the given tags:
          if tags_arg.length == tags.length
            tags.each_with_index do |tag, index|
              sql_alias = ['t', index].join
              result = result.joins("INNER JOIN topic_tags #{sql_alias} ON #{sql_alias}.topic_id = topics.id AND #{sql_alias}.tag_id = #{tag}")
            end
          else
            result = result.none # don't return any results unless all tags exist in the database
          end
        else
          # ANY of the given tags:
          result = result.joins(:tags).where("tags.id in (?)", tags)
        end

        # TODO: this is very side-effecty and should be changed
        # It is done cause further up we expect normalized tags
        @options[:tags] = tags

      elsif @options[:no_tags]
        # the following will do: ("topics"."id" NOT IN (SELECT DISTINCT "topic_tags"."topic_id" FROM "topic_tags"))
        result = result.where.not(id: TopicTag.distinct.pluck(:topic_id))
      end
    end

    result = apply_ordering(result, options)
    result = result.listable_topics

    # Don't include the category topics if excluded
    if options[:no_definitions]
      result = result.where('COALESCE(categories.topic_id, 0) <> topics.id')
    end

    result = result.limit(options[:per_page]) unless options[:limit] == false
    result = result.visible if options[:visible]
    result = result.where.not(topics: { id: options[:except_topic_ids] }).references(:topics) if options[:except_topic_ids]

    if options[:page]
      offset = options[:page].to_i * options[:per_page]
      result = result.offset(offset) if offset > 0
    end

    if options[:topic_ids]
      result = result.where('topics.id in (?)', options[:topic_ids]).references(:topics)
    end

    if search = options[:search]
      result = result.where("topics.id in (select pp.topic_id from post_search_data pd join posts pp on pp.id = pd.post_id where pd.search_data @@ #{Search.ts_query(term: search.to_s)})")
    end

    # NOTE protect against SYM attack can be removed with Ruby 2.2
    #
    state = options[:state]
    if @user && state &&
        TopicUser.notification_levels.keys.map(&:to_s).include?(state)
      level = TopicUser.notification_levels[state.to_sym]
      result = result.where('topics.id IN (
                                SELECT topic_id
                                FROM topic_users
                                WHERE user_id = ? AND
                                      notification_level = ?)', @user.id, level)
    end

    require_deleted_clause = true

    if before = options[:before]
      if (before = before.to_i) > 0
        result = result.where('topics.created_at < ?', before.to_i.days.ago)
      end
    end

    if bumped_before = options[:bumped_before]
      if (bumped_before = bumped_before.to_i) > 0
        result = result.where('topics.bumped_at < ?', bumped_before.to_i.days.ago)
      end
    end

    if status = options[:status]
      case status
      when 'open'
        result = result.where('NOT topics.closed AND NOT topics.archived')
      when 'closed'
        result = result.where('topics.closed')
      when 'archived'
        result = result.where('topics.archived')
      when 'listed'
        result = result.where('topics.visible')
      when 'unlisted'
        result = result.where('NOT topics.visible')
      when 'deleted'
        guardian = @guardian
        if guardian.is_staff?
          result = result.where('topics.deleted_at IS NOT NULL')
          require_deleted_clause = false
        end
      end
    end

    if (filter = options[:filter]) && @user
      action =
        if filter == "bookmarked"
          PostActionType.types[:bookmark]
        elsif filter == "liked"
          PostActionType.types[:like]
        end
      if action
        result = result.where('topics.id IN (SELECT pp.topic_id
                              FROM post_actions pa
                              JOIN posts pp ON pp.id = pa.post_id
                              WHERE pa.user_id = :user_id AND
                                    pa.post_action_type_id = :action AND
                                    pa.deleted_at IS NULL
                           )', user_id: @user.id,
                               action: action
                           )
      end
    end

    result = result.where('topics.deleted_at IS NULL') if require_deleted_clause
    result = result.where('topics.posts_count <= ?', options[:max_posts]) if options[:max_posts].present?
    result = result.where('topics.posts_count >= ?', options[:min_posts]) if options[:min_posts].present?

    result = TopicQuery.apply_custom_filters(result, self)

    @guardian.filter_allowed_categories(result)
  end

  def remove_muted_topics(list, user)
    if user
      list = list.where('COALESCE(tu.notification_level,1) > :muted', muted: TopicUser.notification_levels[:muted])
    end

    list
  end

  def remove_muted_categories(list, user, opts = nil)
    category_id = get_category_id(opts[:exclude]) if opts

    if user
      list = list
        .references("cu")
        .joins("LEFT JOIN category_users ON category_users.category_id = topics.category_id AND category_users.user_id = #{user.id}")
        .where("topics.category_id = :category_id
                OR COALESCE(category_users.notification_level, :default) <> :muted
                OR tu.notification_level > :regular",
                category_id: category_id || -1,
                default: CategoryUser.default_notification_level,
                muted: CategoryUser.notification_levels[:muted],
                regular: TopicUser.notification_levels[:regular])
    elsif SiteSetting.mute_all_categories_by_default
      category_ids = [
        SiteSetting.default_categories_watching.split("|"),
        SiteSetting.default_categories_tracking.split("|"),
        SiteSetting.default_categories_watching_first_post.split("|")
      ].flatten.map(&:to_i)
      category_ids << category_id if category_id.present? && category_ids.exclude?(category_id)

      list = list.where("topics.category_id IN (?)", category_ids) if category_ids.present?
    else
      category_ids = SiteSetting.default_categories_muted.split("|").map(&:to_i)
      category_ids -= [category_id] if category_id.present? && category_ids.include?(category_id)

      list = list.where("topics.category_id NOT IN (?)", category_ids) if category_ids.present?
    end

    list
  end

  def remove_muted_tags(list, user, opts = nil)
    if user.nil? || !SiteSetting.tagging_enabled || SiteSetting.remove_muted_tags_from_latest == 'never'
      return list
    end

    muted_tag_ids = TagUser.lookup(user, :muted).pluck(:tag_id)
    if muted_tag_ids.blank?
      return list
    end

    # if viewing the topic list for a muted tag, show all the topics
    if !opts[:no_tags] && opts[:tags].present?
      return list if TagUser.lookup(user, :muted).joins(:tag).where('tags.name = ?', opts[:tags].first).exists?
    end

    if SiteSetting.remove_muted_tags_from_latest == 'always'
      list = list.where("
        NOT EXISTS(
          SELECT 1
            FROM topic_tags tt
           WHERE tt.tag_id IN (:tag_ids)
             AND tt.topic_id = topics.id)", tag_ids: muted_tag_ids)
    else
      list = list.where("
        EXISTS (
          SELECT 1
            FROM topic_tags tt
           WHERE tt.tag_id NOT IN (:tag_ids)
             AND tt.topic_id = topics.id
        ) OR NOT EXISTS (SELECT 1 FROM topic_tags tt WHERE tt.topic_id = topics.id)", tag_ids: muted_tag_ids)
    end
  end

  def remove_already_seen_for_category(list, user)
    if user
      list = list
        .where("category_users.last_seen_at IS NULL OR topics.created_at > category_users.last_seen_at")
    end

    list
  end

  def new_messages(params)
    query = TopicQuery
      .new_filter(messages_for_groups_or_user(params[:my_group_ids]), Time.at(SiteSetting.min_new_topics_time).to_datetime)
      .limit(params[:count])
    query
  end

  def unread_messages(params)
    query = TopicQuery.unread_filter(
      messages_for_groups_or_user(params[:my_group_ids]),
      @user&.id,
      staff: @user&.staff?)
      .limit(params[:count])
    query
  end

  def related_messages_user(params)
    messages = messages_for_user.limit(params[:count])
    messages = allowed_messages(messages, params)
  end

  def related_messages_group(params)
    messages = messages_for_groups_or_user(params[:my_group_ids]).limit(params[:count])
    messages = allowed_messages(messages, params)
  end

  def allowed_messages(messages, params)
    user_ids = (params[:target_user_ids] || [])
    group_ids = ((params[:target_group_ids] - params[:my_group_ids]) || [])

    if user_ids.present?
      messages =
        messages.joins("
          LEFT JOIN topic_allowed_users ta2
          ON topics.id = ta2.topic_id
          AND ta2.user_id IN (#{sanitize_sql_array(user_ids)})
        ")
    end

    if group_ids.present?
      messages =
        messages.joins("
          LEFT JOIN topic_allowed_groups tg2
          ON topics.id = tg2.topic_id
          AND tg2.group_id IN (#{sanitize_sql_array(group_ids)})
        ")
    end

    messages =
      if user_ids.present? && group_ids.present?
        messages.where("ta2.topic_id IS NOT NULL OR tg2.topic_id IS NOT NULL")
      elsif user_ids.present?
        messages.where("ta2.topic_id IS NOT NULL")
      elsif group_ids.present?
        messages.where("tg2.topic_id IS NOT NULL")
      end
  end

  def messages_for_groups_or_user(group_ids)
    if group_ids.present?
      base_messages
        .joins("
          LEFT JOIN (
            SELECT * FROM topic_allowed_groups _tg
            LEFT JOIN group_users gu
            ON gu.user_id = #{@user.id.to_i}
            AND gu.group_id = _tg.group_id
            WHERE gu.group_id IN (#{sanitize_sql_array(group_ids)})
          ) tg ON topics.id = tg.topic_id
        ")
        .where("tg.topic_id IS NOT NULL")
    else
      messages_for_user
    end
  end

  def messages_for_user
    base_messages
      .joins("
        LEFT JOIN topic_allowed_users ta
        ON topics.id = ta.topic_id
        AND ta.user_id = #{@user.id.to_i}
      ")
      .where("ta.topic_id IS NOT NULL")
  end

  def base_messages
    query = Topic
      .where('topics.archetype = ?', Archetype.private_message)
      .joins("LEFT JOIN topic_users tu ON topics.id = tu.topic_id AND tu.user_id = #{@user.id.to_i}")

    query = query.includes(:tags) if SiteSetting.tagging_enabled
    query.order('topics.bumped_at DESC')
  end

  def random_suggested(topic, count, excluded_topic_ids = [])
    result = default_results(unordered: true, per_page: count).where(closed: false, archived: false)

    if SiteSetting.limit_suggested_to_category
      excluded_topic_ids += Category.where(id: topic.category_id).pluck(:id)
    else
      excluded_topic_ids += Category.topic_ids.to_a
    end
    result = result.where("topics.id NOT IN (?)", excluded_topic_ids) unless excluded_topic_ids.empty?

    result = remove_muted_categories(result, @user)

    # If we are in a category, prefer it for the random results
    if topic.category_id
      result = result.order("CASE WHEN topics.category_id = #{topic.category_id.to_i} THEN 0 ELSE 1 END")
    end

    # Best effort, it over selects, however if you have a high number
    # of muted categories there is tiny chance we will not select enough
    # in particular this can happen if current category is empty and tons
    # of muted, big edge case
    #
    # we over select in case cache is stale
    max = (count * 1.3).to_i
    ids = SiteSetting.limit_suggested_to_category ? [] : RandomTopicSelector.next(max)
    ids.concat(RandomTopicSelector.next(max, topic.category))

    result.where(id: ids.uniq)
  end

  def suggested_ordering(result, options)
    # Prefer unread in the same category
    if options[:topic] && options[:topic].category_id
      result = result.order("CASE WHEN topics.category_id = #{options[:topic].category_id.to_i} THEN 0 ELSE 1 END")
    end

    result.order('topics.bumped_at DESC')
  end

  private

  def sanitize_sql_array(input)
    ActiveRecord::Base.public_send(:sanitize_sql_array, input.join(','))
  end

  def append_read_state(list, group)
    group_id = group&.id
    return list if group_id.nil?

    selected_values = list.select_values.empty? ? ['topics.*'] : list.select_values
    selected_values << "COALESCE(tg.last_read_post_number, 0) AS last_read_post_number"

    list
      .joins("LEFT OUTER JOIN topic_groups tg ON topics.id = tg.topic_id AND tg.group_id = #{group_id}")
      .select(*selected_values)
  end
end
