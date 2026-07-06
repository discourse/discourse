# frozen_string_literal: true

class DiscourseSolved::SolvedTopicsController < ::ApplicationController
  requires_plugin DiscourseSolved::PLUGIN_NAME

  def by_user
    params.require(:username)
    user =
      fetch_user_from_params(
        include_inactive:
          current_user.try(:staff?) || (current_user && SiteSetting.show_inactive_accounts),
      )
    raise Discourse::NotFound unless guardian.public_can_see_profiles?
    raise Discourse::NotFound unless guardian.can_see_profile?(user)

    offset = [0, params[:offset].to_i].max
    limit = params.fetch(:limit, 30).to_i

    include_unlisted_topics = current_user&.id == user.id || guardian.can_see_unlisted_topics?

    posts =
      Post
        .joins(
          "INNER JOIN discourse_solved_topic_answers ON discourse_solved_topic_answers.answer_post_id = posts.id",
          "INNER JOIN discourse_solved_solved_topics ON discourse_solved_solved_topics.id = discourse_solved_topic_answers.solved_topic_id",
        )
        .joins(:topic)
        .joins("LEFT JOIN categories ON categories.id = topics.category_id")
        .where(user_id: user.id, deleted_at: nil)
        .where(topics: { archetype: Archetype.default, deleted_at: nil })
        .where(
          "topics.category_id IS NULL OR NOT categories.read_restricted OR topics.category_id IN (:secure_category_ids)",
          secure_category_ids: guardian.secure_category_ids,
        )

    posts = posts.where(topics: { visible: true }) unless include_unlisted_topics
    posts = guardian.filter_hidden_posts(posts)

    unless guardian.is_admin?
      current_user_id = current_user&.id || -1
      posts =
        posts.where(
          "posts.user_id = :current_user_id OR posts.post_type IN (:visible_post_types)",
          current_user_id:,
          visible_post_types: Topic.visible_post_types(current_user),
        )
    end

    posts =
      posts
        .includes(:user, topic: %i[category tags])
        .order("discourse_solved_topic_answers.created_at DESC")
        .offset(offset)
        .limit(limit)

    posts = posts.select { |post| guardian.can_see_post?(post) }

    render_serialized(posts, DiscourseSolved::SolvedPostSerializer, root: "user_solved_posts")
  end
end
