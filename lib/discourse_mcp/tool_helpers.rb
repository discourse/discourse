# frozen_string_literal: true

module DiscourseMcp
  module ToolHelpers
    MAX_READ_LENGTH = 50_000

    module_function

    def text_and_structured(value)
      {
        content: [{ type: "text", text: JSON.generate(value) }],
        structuredContent: value,
        isError: false,
      }
    end

    def post_json(post)
      {
        id: post.id,
        topic_id: post.topic_id,
        post_number: post.post_number,
        username: post.username,
        raw: post.raw,
        created_at: post.created_at.iso8601,
        updated_at: post.updated_at.iso8601,
        url: post.full_url,
      }
    end

    def topic_json(topic, guardian, visible_tag_ids: nil)
      visible_tag_ids ||= self.visible_tag_ids([topic], guardian)

      {
        id: topic.id,
        title: topic.title,
        slug: topic.slug,
        category_id: topic.category_id,
        tags: topic.tags.select { |tag| visible_tag_ids.include?(tag.id) }.map(&:name),
        posts_count: topic.posts_count,
        created_at: topic.created_at.iso8601,
        last_posted_at: topic.last_posted_at&.iso8601,
        closed: topic.closed,
        archived: topic.archived,
        url: topic.url,
      }
    end

    def discovery_topic_json(topic, visible_tag_ids)
      posters = topic.posters || topic.posters_summary
      latest_poster = posters.find { |poster| poster.extras.to_s.split.include?("latest") }

      {
        id: topic.id,
        slug: topic.slug,
        title: topic.title,
        category_id: topic.category_id,
        tags: topic.tags.select { |tag| visible_tag_ids.include?(tag.id) }.map(&:name),
        created_at: topic.created_at.iso8601,
        last_posted_at: topic.last_posted_at&.iso8601,
        bumped_at: topic.bumped_at&.iso8601,
        posts_count: topic.posts_count,
        reply_count: topic.reply_count,
        views: topic.views,
        like_count: topic.like_count,
        posters_count: topic.participant_count,
        closed: topic.closed,
        archived: topic.archived,
        pinned: PinnedCheck.pinned?(topic, topic.user_data),
        visible: topic.visible,
        last_poster_username: latest_poster&.user&.username,
        posters:
          posters.map do |poster|
            {
              user_id: poster.user&.id,
              username: poster.user&.username,
              description: poster.description,
            }
          end,
      }
    end

    def evidence_post_json(post, excerpt: nil, include_raw: false)
      user = post.user
      topic = post.topic
      result = {
        id: post.id,
        topic_id: post.topic_id,
        post_number: post.post_number,
        post_type: post.post_type,
        username: user&.username,
        user_id: post.user_id,
        name: SiteSetting.enable_names? ? user&.name : nil,
        created_at: post.created_at.iso8601,
        updated_at: post.updated_at.iso8601,
        excerpt: excerpt,
        reply_to_post_number: post.reply_to_post_number,
        reply_count: post.reply_count,
        like_count: post.like_count,
        category_id: topic&.category_id,
        topic_slug: topic&.slug,
        topic_title: topic&.title,
        staff: user&.staff?,
        moderator: user&.moderator?,
        admin: user&.admin?,
        hidden: post.hidden,
        deleted_at: post.deleted_at&.iso8601,
      }

      if include_raw
        result[:raw] = post.raw.to_s.first(MAX_READ_LENGTH)
        result[:truncated] = post.raw.to_s.length > MAX_READ_LENGTH
      end

      %i[accepted_answer topic_accepted_answer].each do |field|
        result[field] = post.public_send(field) if post.respond_to?(field)
      end
      result
    end

    def visible_tag_ids(topics, guardian)
      DiscourseTagging.visible_tag_ids(topics.flat_map(&:tags), guardian)
    end

    def post_excerpt(post, guardian)
      cooked = ContentLocalization.translated_post_cooked(post, guardian)
      cooked ? Post.excerpt(cooked, nil, post:) : post.excerpt
    end

    def visible_user!(username, guardian)
      user = User.find_by_username(username)
      if user.blank? || !guardian.can_see_profile?(user)
        raise DiscourseMcp::ToolError, I18n.t("mcp.errors.user_not_found")
      end

      user
    end

    def visible_post!(post_id, guardian)
      post = Post.with_deleted.find_by(id: post_id)
      topic = Topic.with_deleted.find_by(id: post&.topic_id)
      post.association(:topic).target = topic if post && topic

      if post.blank? || topic.blank? || !guardian.can_see?(topic) || !guardian.can_see?(post)
        raise DiscourseMcp::ToolError, I18n.t("mcp.errors.post_not_found")
      end

      post
    end

    def ensure_current_author!(arguments, user)
      requested_author = arguments["author_username"]
      return if requested_author.blank? || requested_author.casecmp?(user.username)

      raise Discourse::InvalidAccess
    end

    def user_post_json(action)
      {
        id: action.post_id || action.id,
        topic_id: action.topic_id,
        post_number: action.post_number,
        slug: Slug.for(action.title),
        title: action.title,
        created_at: action.created_at&.iso8601,
        excerpt:
          (
            if action.cooked.present?
              PrettyText.excerpt(action.cooked, 300, keep_emoji_images: true)
            else
              nil
            end
          ),
        category_id: action.category_id,
      }
    end
  end
end
