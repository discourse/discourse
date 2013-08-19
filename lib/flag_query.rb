module FlagQuery
  def self.flagged_posts_report(filter, offset = 0, per_page = 25)

    actions = flagged_post_actions(filter)

    post_ids = actions
              .limit(per_page)
              .offset(offset)
              .group(:post_id)
              .order('min(post_actions.created_at) DESC')
              .pluck(:post_id).uniq

    return nil if post_ids.blank?

    actions = actions
                .order('post_actions.created_at DESC')
                .includes({:related_post => :topic})

    posts = SqlBuilder.new("SELECT p.id, t.title, p.cooked, p.user_id,
      p.topic_id, p.post_number, p.hidden, t.visible topic_visible,
      p.deleted_at, t.deleted_at topic_deleted_at
      FROM posts p
      JOIN topics t ON t.id = p.topic_id
      WHERE p.id in (:post_ids)").map_exec(OpenStruct, post_ids: post_ids)

    post_lookup = {}
    users = Set.new

    posts.each do |p|
      users << p.user_id
      p.excerpt = Post.excerpt(p.cooked)
      p.topic_slug = Slug.for(p.title)
      post_lookup[p.id] = p
    end

    # maintain order
    posts = post_ids.map{|id| post_lookup[id]}

    post_actions = actions.where(:post_id => post_ids)

    post_actions.each do |pa|
      post = post_lookup[pa.post_id]
      post.post_actions ||= []
      action = pa.attributes
      action[:name_key] = PostActionType.types.key(pa.post_action_type_id)
      if (pa.related_post && pa.related_post.topic)
        action.merge!(topic_id: pa.related_post.topic_id,
                     slug: pa.related_post.topic.slug,
                     permalink: pa.related_post.topic.url)
      end
      post.post_actions << action
      users << pa.user_id
    end

    # TODO add serializer so we can skip this
    posts.map!(&:marshal_dump)
    [posts, User.where(id: users.to_a).to_a]
  end

  protected

  def self.flagged_post_ids(filter, offset, limit)
    sql = <<SQL

    SELECT p.id from posts p
    JOIN topics t ON t.id = p.topic_id
    WHERE p.id IN (
      SELECT post_id from post_actions
      WHERE
    )
    /*offset*/
    /*limit*/

SQL
  end

  def self.flagged_post_actions(filter)
    post_actions = PostAction
                      .where(post_action_type_id: PostActionType.notify_flag_type_ids)
                      .joins(:post => :topic)

    if filter == 'old'
      post_actions
        .with_deleted
        .where('post_actions.deleted_at IS NOT NULL OR
                defer = true OR
                topics.deleted_at IS NOT NULL OR
                posts.deleted_at IS NOT NULL')
    else
      post_actions
        .where('defer IS NULL OR
                defer = false')
        .where('posts.deleted_at IS NULL AND
                topics.deleted_at IS NULL')
    end
  end
end
