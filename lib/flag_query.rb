# frozen_string_literal: true

require 'ostruct'

module FlagQuery

  def self.plugin_post_custom_fields
    @plugin_post_custom_fields ||= {}
  end

  # Allow plugins to add custom fields to the flag views
  def self.register_plugin_post_custom_field(field, plugin)
    plugin_post_custom_fields[field] = plugin
  end

  def self.flagged_posts_report(current_user, opts = nil)
    Discourse.deprecate("FlagQuery is deprecated, use the Reviewable API instead.", since: "2.3.0beta5", drop_from: "2.4")

    opts ||= {}
    offset = opts[:offset] || 0
    per_page = opts[:per_page] || 25

    reviewables = ReviewableFlaggedPost.default_visible.viewable_by(current_user, order: 'created_at DESC')
    reviewables = reviewables.where(topic_id: opts[:topic_id]) if opts[:topic_id]
    reviewables = reviewables.where(target_created_by_id: opts[:user_id]) if opts[:user_id]
    reviewables = reviewables.limit(per_page).offset(offset)

    if opts[:filter] == 'old'
      reviewables = reviewables.where("status <> ?", Reviewable.statuses[:pending])
    else
      reviewables = reviewables.pending
    end

    total_rows = reviewables.count

    post_ids = reviewables.map(&:target_id).uniq

    posts = DB.query(<<~SQL, post_ids: post_ids)
      SELECT p.id,
             p.cooked as excerpt,
             p.raw,
             p.user_id,
             p.topic_id,
             p.post_number,
             p.reply_count,
             p.hidden,
             p.deleted_at,
             p.user_deleted,
             NULL as post_action_ids,
             (SELECT created_at FROM post_revisions WHERE post_id = p.id AND user_id = p.user_id ORDER BY created_at DESC LIMIT 1) AS last_revised_at,
             (SELECT COUNT(*) FROM post_actions WHERE (disagreed_at IS NOT NULL OR agreed_at IS NOT NULL OR deferred_at IS NOT NULL) AND post_id = p.id)::int AS previous_flags_count
        FROM posts p
       WHERE p.id in (:post_ids)
    SQL

    post_lookup = {}
    user_ids = Set.new
    topic_ids = Set.new

    posts.each do |p|
      user_ids << p.user_id
      topic_ids << p.topic_id
      p.excerpt = Post.excerpt(p.excerpt)
      post_lookup[p.id] = p
    end

    all_post_actions = []
    reviewables.each do |r|
      post = post_lookup[r.target_id]
      post.post_action_ids ||= []

      r.reviewable_scores.order('created_at desc').each do |rs|
        action = {
          id: rs.id,
          post_id: post.id,
          user_id: rs.user_id,
          post_action_type_id: rs.reviewable_score_type,
          created_at: rs.created_at,
          disposed_by_id: rs.reviewed_by_id,
          disposed_at: rs.reviewed_at,
          disposition: ReviewableScore.statuses[rs.status],
          targets_topic: r.payload['targets_topic'],
          staff_took_action: rs.took_action?
        }
        action[:name_key] = PostActionType.types.key(rs.reviewable_score_type)

        if rs.meta_topic.present?
          meta_posts = rs.meta_topic.ordered_posts

          conversation = {}
          if response = meta_posts[0]
            action[:related_post_id] = response.id

            conversation[:response] = {
              excerpt: excerpt(response.cooked),
              user_id: response.user_id
            }
            user_ids << response.user_id
            if reply = meta_posts[1]
              conversation[:reply] = {
                excerpt: excerpt(reply.cooked),
                user_id: reply.user_id
              }
              user_ids << reply.user_id
              conversation[:has_more] = rs.meta_topic.posts_count > 2
            end
          end

          action.merge!(permalink: rs.meta_topic.relative_url, conversation: conversation)
        end

        post.post_action_ids << action[:id]
        all_post_actions << action
        user_ids << action[:user_id]
        user_ids << rs.reviewed_by_id if rs.reviewed_by_id
      end
    end

    post_custom_field_names = []
    plugin_post_custom_fields.each do |field, plugin|
      post_custom_field_names << field if plugin.enabled?
    end

    post_custom_fields = Post.custom_fields_for_ids(post_ids, post_custom_field_names)

    # maintain order
    posts = post_ids.map { |id| post_lookup[id] }

    # TODO: add serializer so we can skip this
    posts.map! do |post|
      result = post.to_h
      if cfs = post_custom_fields[post.id]
        result[:custom_fields] = cfs
      end
      result
    end

    guardian = Guardian.new(current_user)
    users = User.includes(:user_stat).where(id: user_ids.to_a).to_a
    User.preload_custom_fields(users, User.whitelisted_user_custom_fields(guardian))

    [
      posts,
      Topic.with_deleted.where(id: topic_ids.to_a).to_a,
      users,
      all_post_actions,
      total_rows
    ]
  end

  def self.flagged_post_actions(opts = nil)
    Discourse.deprecate("FlagQuery is deprecated, please use the Reviewable API instead.", since: "2.3.0beta5", drop_from: "2.4")

    opts ||= {}

    scores = ReviewableScore.includes(:reviewable).where('reviewables.type' => 'ReviewableFlaggedPost')
    scores = scores.where('reviewables.topic_id' => opts[:topic_id]) if opts[:topic_id]
    scores = scores.where('reviewables.target_created_by_id' => opts[:user_id]) if opts[:user_id]

    if opts[:filter] == 'without_custom'
      return scores.where(reviewable_score_type: PostActionType.flag_types_without_custom.values)
    end

    if opts[:filter] == "old"
      scores = scores.where('reviewables.status <> ?', Reviewable.statuses[:pending])
    else
      scores = scores.where('reviewables.status' => Reviewable.statuses[:pending])
    end

    scores
  end

  def self.flagged_topics
    Discourse.deprecate("FlagQuery has been deprecated. Please use the Reviewable API instead.", since: "2.3.0beta5", drop_from: "2.4")

    params = {
      pending: Reviewable.statuses[:pending],
      min_score: Reviewable.min_score_for_priority
    }

    results = DB.query(<<~SQL, params)
      SELECT rs.reviewable_score_type,
        p.id AS post_id,
        r.topic_id,
        rs.created_at,
        p.user_id
      FROM reviewables AS r
      INNER JOIN reviewable_scores AS rs ON rs.reviewable_id = r.id
      INNER JOIN posts AS p ON p.id = r.target_id
      WHERE r.type = 'ReviewableFlaggedPost'
        AND r.status = :pending
        AND r.score >= :min_score
      ORDER BY rs.created_at DESC
    SQL

    ft_by_id = {}
    user_ids = Set.new

    results.each do |r|
      ft = ft_by_id[r.topic_id] ||= OpenStruct.new(
        topic_id: r.topic_id,
        flag_counts: {},
        user_ids: Set.new,
        last_flag_at: r.created_at,
      )

      ft.flag_counts[r.reviewable_score_type] ||= 0
      ft.flag_counts[r.reviewable_score_type] += 1

      ft.user_ids << r.user_id
      user_ids << r.user_id
    end

    all_topics = Topic.where(id: ft_by_id.keys).to_a
    all_topics.each { |t| ft_by_id[t.id].topic = t }

    Topic.preload_custom_fields(all_topics, TopicList.preloaded_custom_fields)
    {
      flagged_topics: ft_by_id.values,
      users: User.where(id: user_ids)
    }
  end
end
