module FlagQuery

  def self.flagged_posts_report(current_user, filter, offset=0, per_page=25)
    actions = flagged_post_actions(filter)

    guardian = Guardian.new(current_user)

    if !guardian.is_admin?
      actions = actions.where('category_id IN (:allowed_category_ids) OR archetype = :private_message',
        allowed_category_ids: guardian.allowed_category_ids,
        private_message: Archetype.private_message)
    end

    post_ids = actions.limit(per_page)
                      .offset(offset)
                      .group(:post_id)
                      .order('MIN(post_actions.created_at) DESC')
                      .pluck(:post_id)
                      .uniq

    return nil if post_ids.blank?

    posts = SqlBuilder.new("
      SELECT p.id,
             p.cooked,
             p.user_id,
             p.topic_id,
             p.post_number,
             p.hidden,
             p.deleted_at,
             p.user_deleted,
             (SELECT created_at FROM post_revisions WHERE post_id = p.id AND user_id = p.user_id ORDER BY created_at DESC LIMIT 1) AS last_revised_at,
             (SELECT COUNT(*) FROM post_actions WHERE (disagreed_at IS NOT NULL OR agreed_at IS NOT NULL OR deferred_at IS NOT NULL) AND post_id = p.id)::int AS previous_flags_count
        FROM posts p
       WHERE p.id in (:post_ids)").map_exec(OpenStruct, post_ids: post_ids)

    post_lookup = {}
    user_ids = Set.new
    topic_ids = Set.new

    posts.each do |p|
      user_ids << p.user_id
      topic_ids << p.topic_id
      p.excerpt = Post.excerpt(p.cooked)
      p.delete_field(:cooked)
      post_lookup[p.id] = p
    end

    post_actions = actions.order('post_actions.created_at DESC')
                          .includes(related_post: { topic: { ordered_posts: :user }})
                          .where(post_id: post_ids)

    post_actions.each do |pa|
      post = post_lookup[pa.post_id]
      post.post_actions ||= []
      # TODO: add serializer so we can skip this
      action = {
        id: pa.id,
        post_id: pa.post_id,
        user_id: pa.user_id,
        post_action_type_id: pa.post_action_type_id,
        created_at: pa.created_at,
        disposed_by_id: pa.disposed_by_id,
        disposed_at: pa.disposed_at,
        disposition: pa.disposition,
        related_post_id: pa.related_post_id,
        targets_topic: pa.targets_topic,
        staff_took_action: pa.staff_took_action
      }
      action[:name_key] = PostActionType.types.key(pa.post_action_type_id)

      if pa.related_post && pa.related_post.topic
        conversation = {}
        related_topic = pa.related_post.topic
        if response = related_topic.ordered_posts[0]
          conversation[:response] = {
            excerpt: excerpt(response.cooked),
            user_id: response.user_id
          }
          user_ids << response.user_id
          if reply = related_topic.ordered_posts[1]
            conversation[:reply] = {
              excerpt: excerpt(reply.cooked),
              user_id: reply.user_id
            }
            user_ids << reply.user_id
            conversation[:has_more] = related_topic.posts_count > 2
          end
        end

        action.merge!(permalink: related_topic.relative_url, conversation: conversation)
      end

      post.post_actions << action

      user_ids << pa.user_id
      user_ids << pa.disposed_by_id if pa.disposed_by_id
    end

    # maintain order
    posts = post_ids.map { |id| post_lookup[id] }
    # TODO: add serializer so we can skip this
    posts.map!(&:marshal_dump)

    [
      posts,
      Topic.with_deleted.where(id: topic_ids.to_a).to_a,
      User.includes(:user_stat).where(id: user_ids.to_a).to_a
    ]
  end

  def self.flagged_post_actions(filter)
    post_actions = PostAction.flags
                             .joins("INNER JOIN posts ON posts.id = post_actions.post_id")
                             .joins("INNER JOIN topics ON topics.id = posts.topic_id")
                             .joins("LEFT JOIN users ON users.id = posts.user_id")

    if filter == "old"
      post_actions.where("post_actions.disagreed_at IS NOT NULL OR
                          post_actions.deferred_at IS NOT NULL OR
                          post_actions.agreed_at IS NOT NULL")
    else
      post_actions.active
                  .where("posts.deleted_at" => nil)
                  .where("topics.deleted_at" => nil)
    end

  end

  private

    def self.excerpt(cooked)
      excerpt = Post.excerpt(cooked, 200)
      # remove the first link if it's the first node
      fragment = Nokogiri::HTML.fragment(excerpt)
      if fragment.children.first == fragment.css("a:first").first && fragment.children.first
        fragment.children.first.remove
      end
      fragment.to_html.strip
    end

end
