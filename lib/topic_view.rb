# frozen_string_literal: true

class TopicView
  MEGA_TOPIC_POSTS_COUNT = 10_000
  MIN_POST_READ_TIME = 4.0

  def self.on_preload(&blk)
    (@preload ||= Set.new) << blk
  end

  def self.cancel_preload(&blk)
    if @preload
      @preload.delete blk
      @preload = nil if @preload.length == 0
    end
  end

  def self.preload(topic_view)
    @preload.each { |preload| preload.call(topic_view) } if @preload
  end

  attr_reader(
    :topic,
    :posts,
    :guardian,
    :filtered_posts,
    :chunk_size,
    :print,
    :message_bus_last_id,
    :queued_posts_enabled,
    :personal_message,
    :can_review_topic,
    :page,
  )
  alias queued_posts_enabled? queued_posts_enabled

  attr_accessor(
    :draft,
    :draft_key,
    :draft_sequence,
    :user_custom_fields,
    :post_custom_fields,
    :post_number,
    :include_suggested,
    :include_related,
  )

  delegate :category, to: :topic, allow_nil: true, private: true
  delegate :require_reply_approval?, to: :category, prefix: true, allow_nil: true, private: true

  def self.print_chunk_size
    1000
  end

  CHUNK_SIZE = 20

  def self.chunk_size
    CHUNK_SIZE
  end

  def self.default_post_custom_fields
    @default_post_custom_fields ||= [Post::NOTICE, "action_code_who", "action_code_path"]
  end

  def self.post_custom_fields_allowlisters
    @post_custom_fields_allowlisters ||= Set.new
  end

  def self.add_post_custom_fields_allowlister(&block)
    post_custom_fields_allowlisters << block
  end

  def self.allowed_post_custom_fields(user, topic)
    wpcf =
      default_post_custom_fields + post_custom_fields_allowlisters.map { |w| w.call(user, topic) }
    wpcf.flatten.uniq
  end

  def self.add_custom_filter(key, &blk)
    custom_filters[key] = blk
  end

  def self.custom_filters
    @custom_filters ||= {}
  end

  # Configure a default scope to be applied to @filtered_posts.
  # The registered block is called with @filtered_posts and an instance of
  # `TopicView`.
  #
  # This API should be considered experimental until it is exposed in
  # `Plugin::Instance`.
  def self.apply_custom_default_scope(&block)
    custom_default_scopes << block
  end

  def self.custom_default_scopes
    @custom_default_scopes ||= []
  end

  # For testing
  def self.reset_custom_default_scopes
    @custom_default_scopes = nil
  end

  def initialize(topic_or_topic_id, user = nil, options = {})
    @topic = find_topic(topic_or_topic_id)
    @user = user
    @guardian = Guardian.new(@user)

    check_and_raise_exceptions(options[:skip_staff_action])

    @message_bus_last_id = MessageBus.last_id("/topic/#{@topic.id}")

    options.each { |key, value| self.instance_variable_set("@#{key}".to_sym, value) }

    @post_number = [@post_number.to_i, 1].max

    @include_suggested = options.fetch(:include_suggested) { true }
    @include_related = options.fetch(:include_related) { true }

    @chunk_size =
      case
      when @print
        TopicView.print_chunk_size
      else
        TopicView.chunk_size
      end

    @limit ||= @chunk_size

    @page = @page.to_i > 1 ? @page.to_i : calculate_page

    setup_filtered_posts
    @filtered_posts = apply_default_scope(@filtered_posts)
    filter_posts(options)

    if @posts && !@skip_custom_fields
      if (added_fields = User.allowed_user_custom_fields(@guardian)).present?
        @user_custom_fields = User.custom_fields_for_ids(@posts.map(&:user_id), added_fields)
      end

      if (allowed_fields = TopicView.allowed_post_custom_fields(@user, @topic)).present?
        @post_custom_fields = Post.custom_fields_for_ids(@posts.map(&:id), allowed_fields)
      end
    end

    TopicView.preload(self)

    @draft_key = @topic.draft_key
    @draft_sequence = DraftSequence.current(@user, @draft_key)

    @can_review_topic = @guardian.can_review_topic?(@topic)
    @queued_posts_enabled = NewPostManager.queue_enabled? || category_require_reply_approval?
    @personal_message = @topic.private_message?
  end

  def user_badges(badge_names)
    return if !badge_names.present?

    user_ids = Set.new
    posts.each { |post| user_ids << post.user_id if post.user_id }

    return if !user_ids.present?

    badges =
      Badge.where("LOWER(name) IN (?)", badge_names.map(&:downcase)).where(enabled: true).to_a

    sql = <<~SQL
     SELECT user_id, badge_id
     FROM user_badges
     WHERE user_id IN (:user_ids) AND badge_id IN (:badge_ids)
     GROUP BY user_id, badge_id
     ORDER BY user_id, badge_id
   SQL

    user_badges = DB.query(sql, user_ids: user_ids, badge_ids: badges.map(&:id))

    user_badge_mapping = {}
    user_badges.each do |user_badge|
      user_badge_mapping[user_badge.user_id] ||= []
      user_badge_mapping[user_badge.user_id] << user_badge.badge_id
    end

    indexed_badges = {}

    badges.each do |badge|
      indexed_badges[badge.id] = {
        id: badge.id,
        name: badge.name,
        slug: badge.slug,
        description: badge.description,
        icon: badge.icon,
        image_url: badge.image_url,
        badge_grouping_id: badge.badge_grouping_id,
        badge_type_id: badge.badge_type_id,
      }
    end

    user_badge_mapping =
      user_badge_mapping
        .map { |user_id, badge_ids| [user_id, { id: user_id, badge_ids: badge_ids }] }
        .to_h

    { users: user_badge_mapping, badges: indexed_badges }
  end

  def post_user_badges
    return [] unless SiteSetting.enable_badges && SiteSetting.show_badges_in_post_header

    @post_user_badges ||=
      begin
        UserBadge
          .for_post_header_badges(@posts)
          .reduce({}) do |hash, user_badge|
            hash[user_badge.post_id] ||= []
            hash[user_badge.post_id] << user_badge
            hash
          end
      end

    return [] unless @post_user_badges

    @post_user_badges
  end

  def show_read_indicator?
    return false if !@user || !topic.private_message?

    topic.allowed_groups.any? { |group| group.publish_read_state? && group.users.include?(@user) }
  end

  def canonical_path
    if SiteSetting.embed_set_canonical_url
      topic_embed = topic.topic_embed
      return topic_embed.embed_url if topic_embed
    end
    current_page_path
  end

  def current_page_path
    if @page > 1
      "#{relative_url}?page=#{@page}"
    else
      relative_url
    end
  end

  def contains_gaps?
    @contains_gaps
  end

  def gaps
    return unless @contains_gaps

    @gaps ||=
      begin
        if is_mega_topic?
          nil
        else
          Gaps.new(filtered_post_ids, apply_default_scope(unfiltered_posts).pluck(:id))
        end
      end
  end

  def last_post
    return nil if @posts.blank?
    @last_post ||= @posts.last
  end

  def prev_page
    @page > 1 && posts.size > 0 ? @page - 1 : nil
  end

  def next_page
    @next_page ||=
      begin
        if last_post && highest_post_number && (highest_post_number > last_post.post_number)
          @page + 1
        end
      end
  end

  def prev_page_path
    if prev_page > 1
      "#{relative_url}?page=#{prev_page}"
    else
      relative_url
    end
  end

  def next_page_path
    "#{relative_url}?page=#{next_page}"
  end

  def absolute_url
    "#{Discourse.base_url_no_prefix}#{relative_url}"
  end

  def relative_url
    "#{@topic.relative_url}#{@print ? "/print" : ""}"
  end

  def page_title
    title = @topic.title
    if @post_number > 1
      title += " - "
      post = @topic.posts.find_by(post_number: @post_number)
      author = post&.user
      if author && @guardian.can_see_post?(post)
        title +=
          I18n.t(
            "inline_oneboxer.topic_page_title_post_number_by_user",
            post_number: @post_number,
            username: author.username,
          )
      else
        title += I18n.t("inline_oneboxer.topic_page_title_post_number", post_number: @post_number)
      end
    elsif @page > 1
      title += " - #{I18n.t("page_num", num: @page)}"
    end

    if SiteSetting.topic_page_title_includes_category
      if @topic.category_id != SiteSetting.uncategorized_category_id && @topic.category_id &&
           @topic.category
        title += " - #{@topic.category.name}"
      elsif SiteSetting.tagging_enabled && visible_tags.exists?
        title +=
          " - #{visible_tags.order("tags.#{Tag.topic_count_column(@guardian)} DESC").first.name}"
      end
    end
    title
  end

  def title
    @topic.title
  end

  def desired_post
    return @desired_post if @desired_post.present?
    return nil if posts.blank?

    @desired_post = posts.detect { |p| p.post_number == @post_number }
    @desired_post ||= posts.first
    @desired_post
  end

  def crawler_posts
    if single_post_request?
      [desired_post]
    else
      posts
    end
  end

  def single_post_request?
    @post_number && @post_number != 1
  end

  def summary(opts = {})
    return nil if desired_post.blank?
    # TODO, this is actually quite slow, should be cached in the post table
    excerpt = desired_post.excerpt(500, opts.merge(strip_links: true, text_entities: true))
    (excerpt || "").gsub(/\n/, " ").strip
  end

  def read_time
    return nil if @post_number > 1 # only show for topic URLs

    if @topic.word_count && SiteSetting.read_time_word_count > 0
      [
        @topic.word_count / SiteSetting.read_time_word_count,
        @topic.posts_count * MIN_POST_READ_TIME / 60,
      ].max.ceil
    end
  end

  def like_count
    return nil if @post_number > 1 # only show for topic URLs
    @topic.like_count
  end

  def published_time
    return nil if desired_post.blank?
    if desired_post.wiki && desired_post.post_number == 1 && desired_post.revisions.size > 0
      desired_post.revisions.last.updated_at.strftime("%FT%T%:z")
    else
      desired_post.created_at.strftime("%FT%T%:z")
    end
  end

  def image_url
    return @topic.image_url if @post_number == 1
    desired_post&.image_url
  end

  def filter_posts(opts = {})
    if opts[:post_number].present?
      filter_posts_near(opts[:post_number].to_i)
    elsif opts[:post_ids].present?
      filter_posts_by_ids(opts[:post_ids])
    elsif opts[:filter_post_number].present?
      # Only used for megatopics where we do not load the entire post stream
      filter_posts_by_post_number(opts[:filter_post_number], opts[:asc])
    elsif opts[:best].present?
      # Only used for wordpress
      filter_best(opts[:best], opts)
    else
      filter_posts_paged(@page)
    end
  end

  def primary_group_names
    return @group_names if @group_names

    primary_group_ids = Set.new
    @posts.each do |p|
      primary_group_ids << p.user.primary_group_id if p.user.try(:primary_group_id)
    end

    result = {}
    unless primary_group_ids.empty?
      Group.where(id: primary_group_ids.to_a).pluck(:id, :name).each { |g| result[g[0]] = g[1] }
    end

    @group_names = result
  end

  # Filter to all posts near a particular post number
  def filter_posts_near(post_number)
    posts_before = (@limit.to_f / 4).floor
    posts_before = 1 if posts_before.zero?
    sort_order = get_sort_order(post_number)

    before_post_ids =
      @filtered_posts
        .reverse_order
        .where("posts.sort_order < ?", sort_order)
        .limit(posts_before)
        .pluck(:id)

    post_ids =
      before_post_ids +
        @filtered_posts
          .where("posts.sort_order >= ?", sort_order)
          .limit(@limit - before_post_ids.length)
          .pluck(:id)

    if post_ids.length < @limit
      post_ids =
        post_ids +
          @filtered_posts
            .reverse_order
            .where("posts.sort_order < ?", sort_order)
            .offset(before_post_ids.length)
            .limit(@limit - post_ids.length)
            .pluck(:id)
    end

    filter_posts_by_ids(post_ids)
  end

  def filter_posts_paged(page)
    page = [page, 1].max
    min = @limit * (page - 1)

    # Sometimes we don't care about the OP, for example when embedding comments
    min = 1 if min == 0 && @exclude_first

    filter_posts_by_ids(@filtered_posts.offset(min).limit(@limit).pluck(:id))
  end

  def filter_best(max, opts = {})
    filter = FilterBestPosts.new(@topic, @filtered_posts, max, opts)
    @posts = filter.posts
    @filtered_posts = filter.filtered_posts
  end

  def read?(post_number)
    return true unless @user
    read_posts_set.include?(post_number)
  end

  def has_deleted?
    @predelete_filtered_posts
      .with_deleted
      .where("posts.deleted_at IS NOT NULL")
      .where("posts.post_number > 1")
      .exists?
  end

  def topic_user
    @topic_user ||=
      begin
        return nil if @user.blank?
        @topic.topic_users.find_by(user_id: @user.id)
      end
  end

  def has_bookmarks?
    bookmarks.any?
  end

  def bookmarks
    return [] if @user.blank?
    return [] if @topic.trashed?

    @bookmarks ||=
      Bookmark.for_user_in_topic(@user, @topic.id).select(
        :id,
        :bookmarkable_id,
        :bookmarkable_type,
        :reminder_at,
        :name,
        :auto_delete_preference,
      )
  end

  MAX_PARTICIPANTS = 24

  def post_counts_by_user
    @post_counts_by_user ||=
      begin
        if is_mega_topic?
          {}
        else
          sql = <<~SQL
            SELECT user_id, count(*) AS count_all
              FROM posts
             WHERE topic_id = :topic_id
               AND post_type IN (:post_types)
               AND user_id IS NOT NULL
               AND posts.deleted_at IS NULL
               AND action_code IS NULL
          GROUP BY user_id
          ORDER BY count_all DESC
             LIMIT #{MAX_PARTICIPANTS}
        SQL

          Hash[
            *DB.query_single(
              sql,
              topic_id: @topic.id,
              post_types: Topic.visible_post_types(@guardian&.user),
            )
          ]
        end
      end
  end

  # if a topic has more that N posts no longer attempt to
  # get accurate participant count, instead grab cached count
  # from topic
  MAX_POSTS_COUNT_PARTICIPANTS = 500

  def participant_count
    @participant_count ||=
      begin
        if participants.size == MAX_PARTICIPANTS
          if @topic.posts_count > MAX_POSTS_COUNT_PARTICIPANTS
            @topic.participant_count
          else
            sql = <<~SQL
              SELECT COUNT(DISTINCT user_id)
              FROM posts
              WHERE id IN (:post_ids)
              AND user_id IS NOT NULL
            SQL
            DB.query_single(sql, post_ids: unfiltered_post_ids).first.to_i
          end
        else
          participants.size
        end
      end
  end

  def participants
    @participants ||=
      begin
        participants = {}
        User
          .where(id: post_counts_by_user.keys)
          .includes(:primary_group, :flair_group)
          .each { |u| participants[u.id] = u }
        participants
      end
  end

  def topic_allowed_group_ids
    @topic_allowed_group_ids ||=
      begin
        @topic.allowed_groups.map(&:id)
      end
  end

  def group_allowed_user_ids
    return @group_allowed_user_ids unless @group_allowed_user_ids.nil?

    @group_allowed_user_ids =
      GroupUser.where(group_id: topic_allowed_group_ids).pluck("distinct user_id")
  end

  def category_group_moderator_user_ids
    @category_group_moderator_user_ids ||=
      begin
        if SiteSetting.enable_category_group_moderation? && @topic.category.present?
          posts_user_ids = Set.new(@posts.map(&:user_id))
          Set.new(
            GroupUser
              .joins(
                "INNER JOIN category_moderation_groups ON category_moderation_groups.group_id = group_users.group_id",
              )
              .where(
                "category_moderation_groups.category_id": @topic.category.id,
                user_id: posts_user_ids,
              )
              .distinct
              .pluck(:user_id),
          )
        else
          Set.new
        end
      end
  end

  def all_post_actions
    @all_post_actions ||= PostAction.counts_for(@posts, @user)
  end

  def links
    @links ||= TopicLink.topic_map(@guardian, @topic.id)
  end

  def reviewable_counts
    @reviewable_counts ||=
      begin
        sql = <<~SQL
        SELECT
          target_id,
          MAX(r.id) reviewable_id,
          COUNT(*) total,
          SUM(CASE WHEN s.status = :pending THEN 1 ELSE 0 END) pending
        FROM
          reviewables r
        JOIN
          reviewable_scores s ON reviewable_id = r.id
        WHERE
          r.target_id IN (:post_ids) AND
          r.target_type = 'Post' AND
          COALESCE(s.reason, '') != 'category'
        GROUP BY
          target_id
      SQL

        counts = {}

        DB
          .query(sql, pending: ReviewableScore.statuses[:pending], post_ids: @posts.map(&:id))
          .each do |row|
            counts[row.target_id] = {
              total: row.total,
              pending: row.pending,
              reviewable_id: row.reviewable_id,
            }
          end

        counts
      end
  end

  def pending_posts
    @pending_posts ||=
      ReviewableQueuedPost.pending.where(target_created_by: @user, topic: @topic).order(:created_at)
  end

  def post_action_type_view
    @post_action_type_view ||= PostActionTypeView.new
  end

  def actions_summary
    return @actions_summary unless @actions_summary.nil?

    @actions_summary = []
    return @actions_summary unless post = posts&.first
    post_action_type_view.topic_flag_types.each do |sym, id|
      @actions_summary << {
        id: id,
        count: 0,
        hidden: false,
        can_act:
          @guardian.post_can_act?(
            post,
            sym,
            opts: {
              post_action_type_view: post_action_type_view,
            },
          ),
      }
    end

    @actions_summary
  end

  def link_counts
    # Normal memoizations doesn't work in nil cases, so using the ol' `defined?` trick
    # to memoize more safely, as a modifier could nil this out.
    return @link_counts if defined?(@link_counts)

    @link_counts =
      DiscoursePluginRegistry.apply_modifier(
        :topic_view_link_counts,
        TopicLink.counts_for(@guardian, @topic, posts),
      )
  end

  def pm_params
    @pm_params ||= TopicQuery.new(@user).get_pm_params(topic)
  end

  def suggested_topics
    if @include_suggested
      @suggested_topics ||=
        begin
          kwargs =
            DiscoursePluginRegistry.apply_modifier(
              :topic_view_suggested_topics_options,
              { include_random: true, pm_params: pm_params },
              self,
            )

          TopicQuery.new(@user).list_suggested_for(topic, **kwargs)
        end
    else
      nil
    end
  end

  def related_messages
    if @include_related
      @related_messages ||= TopicQuery.new(@user).list_related_for(topic, pm_params: pm_params)
    else
      nil
    end
  end

  # This is pending a larger refactor, that allows custom orders
  # for now we need to look for the highest_post_number in the stream
  # the cache on topics is not correct if there are deleted posts at
  # the end of the stream (for mods), nor is it correct for filtered
  # streams
  def highest_post_number
    @highest_post_number ||= @filtered_posts.maximum(:post_number)
  end

  def recent_posts
    @filtered_posts.unscope(:order).by_newest.with_user.first(25)
  end

  # Returns an array of [id, days_ago] tuples.
  # `days_ago` is there for the timeline calculations.
  def filtered_post_stream
    @filtered_post_stream ||=
      begin
        posts = @filtered_posts
        columns = [:id]

        if !is_mega_topic?
          columns << "(EXTRACT(EPOCH FROM CURRENT_TIMESTAMP - posts.created_at) / 86400)::INT AS days_ago"
        end

        posts.pluck(*columns)
      end
  end

  def filtered_post_ids
    @filtered_post_ids ||=
      filtered_post_stream.map do |tuple|
        if is_mega_topic?
          tuple
        else
          tuple[0]
        end
      end
  end

  def unfiltered_post_ids
    @unfiltered_post_ids ||=
      begin
        if @contains_gaps
          unfiltered_posts.pluck(:id)
        else
          filtered_post_ids
        end
      end
  end

  def filtered_post_id(post_number)
    @filtered_posts.where(post_number: post_number).pick(:id)
  end

  def is_mega_topic?
    @is_mega_topic ||= (@topic.posts_count >= MEGA_TOPIC_POSTS_COUNT)
  end

  def last_post_id
    @filtered_posts.reverse_order.pick(:id)
  end

  def current_post_number
    if highest_post_number.present?
      post_number > highest_post_number ? highest_post_number : post_number
    end
  end

  def queued_posts_count
    ReviewableQueuedPost.viewable_by(@user).where(topic_id: @topic.id).pending.count
  end

  def published_page
    @topic.published_page
  end

  def mentioned_users
    @mentioned_users ||=
      begin
        mentions = @posts.to_h { |p| [p.id, p.mentions] }.reject { |_, v| v.empty? }
        usernames = mentions.values
        usernames.flatten!
        usernames.uniq!

        users = User.where(username_lower: usernames)
        users = users.includes(:user_option, :user_status) if SiteSetting.enable_user_status
        users = users.index_by(&:username_lower)

        mentions.reduce({}) do |hash, (post_id, post_mentioned_usernames)|
          hash[post_id] = post_mentioned_usernames.map { |username| users[username] }.compact
          hash
        end
      end
  end

  def categories
    @categories ||= [category&.parent_category, category, suggested_topics&.categories].flatten
      .uniq
      .compact
  end

  protected

  def read_posts_set
    @read_posts_set ||=
      begin
        result = Set.new
        return result if @user.blank?
        return result if topic_user.blank?

        post_numbers =
          PostTiming
            .where(topic_id: @topic.id, user_id: @user.id)
            .where(post_number: @posts.pluck(:post_number))
            .pluck(:post_number)

        post_numbers.each { |pn| result << pn }
        result
      end
  end

  private

  def calculate_page
    posts_count =
      is_mega_topic? ? @post_number : unfiltered_posts.where("post_number <= ?", @post_number).count
    ((posts_count - 1) / @limit) + 1
  end

  def get_sort_order(post_number)
    sql = <<~SQL
      SELECT posts.sort_order
      FROM posts
      WHERE posts.post_number = #{post_number.to_i}
      AND posts.topic_id = #{@topic.id.to_i}
      LIMIT 1
    SQL

    sort_order = DB.query_single(sql).first

    if !sort_order
      sql = <<~SQL
        SELECT posts.sort_order
        FROM posts
        WHERE posts.topic_id = #{@topic.id.to_i}
        ORDER BY @(post_number - #{post_number.to_i})
        LIMIT 1
      SQL

      sort_order = DB.query_single(sql).first
    end

    sort_order
  end

  def filter_post_types(posts)
    return posts.where(post_type: Post.types[:regular]) if @only_regular

    visible_types = Topic.visible_post_types(@user)

    if @user.present?
      posts.where("posts.user_id = ? OR post_type IN (?)", @user.id, visible_types)
    else
      posts.where(post_type: visible_types)
    end
  end

  def filter_posts_by_post_number(post_number, asc)
    sort_order = get_sort_order(post_number)

    posts =
      if asc
        @filtered_posts.where("sort_order > ?", sort_order)
      else
        @filtered_posts.reverse_order.where("sort_order < ?", sort_order)
      end

    posts = posts.limit(@limit) if !@skip_limit
    filter_posts_by_ids(posts.pluck(:id))

    @posts = @posts.reverse_order if !asc
  end

  def filter_posts_by_ids(post_ids)
    @posts =
      Post.where(id: post_ids, topic_id: @topic.id).includes(
        { user: %i[primary_group flair_group] },
        :reply_to_user,
        :deleted_by,
        :incoming_email,
        :image_upload,
      )

    @posts = @posts.includes({ user: :user_status }) if SiteSetting.enable_user_status

    @posts = apply_default_scope(@posts)
    @posts = filter_post_types(@posts)
    @posts = @posts.with_deleted if @guardian.can_see_deleted_posts?(@topic.category)
    @posts
  end

  def find_topic(topic_or_topic_id)
    return topic_or_topic_id if topic_or_topic_id.is_a?(Topic)
    # with_deleted covered in #check_and_raise_exceptions
    Topic.with_deleted.includes(:category).find_by(id: topic_or_topic_id)
  end

  def find_post_replies_ids(post_id)
    DB.query_single(<<~SQL, post_id: post_id)
        WITH RECURSIVE breadcrumb(id, reply_to_post_number, topic_id, level) AS (
          SELECT id, reply_to_post_number, topic_id, 0
            FROM posts
          WHERE id = :post_id

          UNION

          SELECT p.id, p.reply_to_post_number, p.topic_id, b.level + 1
            FROM posts AS p
              , breadcrumb AS b
          WHERE b.reply_to_post_number = p.post_number
            AND b.topic_id = p.topic_id
            AND b.level < #{SiteSetting.max_reply_history}
        )
        SELECT id
          FROM breadcrumb
        WHERE id <> :post_id
      ORDER BY id
    SQL
  end

  def unfiltered_posts
    result = filter_post_types(@topic.posts)
    result = result.with_deleted if @guardian.can_see_deleted_posts?(@topic.category)
    result = result.where("user_id IS NOT NULL") if @exclude_deleted_users
    result = result.where(hidden: false) if @exclude_hidden
    result
  end

  def apply_default_scope(scope)
    scope = scope.order(sort_order: :asc)

    self.class.custom_default_scopes.each { |block| scope = block.call(scope, self) }

    scope
  end

  def setup_filtered_posts
    # Certain filters might leave gaps between posts. If that's true, we can return a gap structure
    @contains_gaps = false
    @filtered_posts = unfiltered_posts

    if @user
      sql = <<~SQL
        SELECT ignored_user_id
        FROM ignored_users as ig
        INNER JOIN users as u ON u.id = ig.ignored_user_id
        WHERE ig.user_id = :current_user_id
          AND ig.ignored_user_id <> :current_user_id
          AND NOT u.admin
          AND NOT u.moderator
      SQL

      ignored_user_ids = DB.query_single(sql, current_user_id: @user.id)

      if ignored_user_ids.present?
        @filtered_posts =
          @filtered_posts.where.not("user_id IN (?) AND posts.post_number != 1", ignored_user_ids)
        @contains_gaps = true
      end
    end

    # Filters
    if @filter == "summary"
      @filtered_posts = @filtered_posts.summary(@topic.id)
      @contains_gaps = true
    end

    if @filter.present? && @filter.to_s != "summary" && TopicView.custom_filters[@filter].present?
      @filtered_posts = TopicView.custom_filters[@filter].call(@filtered_posts, self)
    end

    if @best.present?
      @filtered_posts = @filtered_posts.where("posts.post_type = ?", Post.types[:regular])
      @contains_gaps = true
    end

    # Username filters
    if @username_filters.present?
      usernames = @username_filters.map { |u| u.downcase }

      @filtered_posts =
        @filtered_posts.where(
          "
        posts.post_number = 1
        OR posts.user_id IN (SELECT u.id FROM users u WHERE u.username_lower IN (?))
      ",
          usernames,
        )

      @contains_gaps = true
    end

    # Filter replies
    if @replies_to_post_number.present?
      post_id = filtered_post_id(@replies_to_post_number.to_i)
      @filtered_posts =
        @filtered_posts.where(
          "
        posts.post_number = 1
        OR posts.post_number = :post_number
        OR posts.reply_to_post_number = :post_number
        OR posts.id IN (SELECT pr.reply_post_id FROM post_replies pr WHERE pr.post_id = :post_id)",
          { post_number: @replies_to_post_number.to_i, post_id: post_id },
        )

      @contains_gaps = true
    end

    # Show Only Top Level Replies
    if @filter_top_level_replies.present?
      @filtered_posts =
        @filtered_posts.where(
          "
        posts.post_number > 1
        AND posts.reply_to_post_number IS NULL
      ",
        )
    end

    # Reply history
    if @reply_history_for.present?
      post_ids = find_post_replies_ids(@reply_history_for)

      @filtered_posts = @filtered_posts.where("posts.id IN (:post_ids)", post_ids:)
      @contains_gaps = true
    end

    # Filtering upwards
    if @filter_upwards_post_id.present?
      post_ids = find_post_replies_ids(@filter_upwards_post_id) | [@filter_upwards_post_id.to_i]

      @filtered_posts =
        @filtered_posts.where(
          "posts.post_number = 1 OR posts.id IN (:post_ids) OR posts.id > :max_post_id",
          post_ids:,
          max_post_id: post_ids.max,
        )

      @contains_gaps = true
    end

    # Deleted
    # This should be last - don't want to tell the admin about deleted posts that clicking the button won't show
    # copy the filter for has_deleted? method
    @predelete_filtered_posts = @filtered_posts.spawn

    if @guardian.can_see_deleted_posts?(@topic.category) && !@show_deleted && has_deleted?
      @filtered_posts = @filtered_posts.where("posts.deleted_at IS NULL OR posts.post_number = 1")

      @contains_gaps = true
    end
  end

  def check_and_raise_exceptions(skip_staff_action)
    raise Discourse::NotFound if @topic.blank?
    # Special case: If the topic is private and the user isn't logged in, ask them
    # to log in!
    raise Discourse::NotLoggedIn.new if @topic.present? && @topic.private_message? && @user.blank?
    # can user see this topic?
    unless @guardian.can_see?(@topic)
      raise Discourse::InvalidAccess.new("can't see #{@topic}", @topic)
    end
    # log personal message views
    if SiteSetting.log_personal_messages_views && !skip_staff_action && @topic.present? &&
         @topic.private_message? && @topic.all_allowed_users.where(id: @user.id).blank?
      unless UserHistory
               .where(
                 acting_user_id: @user.id,
                 action: UserHistory.actions[:check_personal_message],
                 topic_id: @topic.id,
               )
               .where("created_at > ?", 1.hour.ago)
               .exists?
        StaffActionLogger.new(@user).log_check_personal_message(@topic)
      end
    end
  end

  def visible_tags
    @visible_tags ||= topic.tags.visible(guardian)
  end
end
