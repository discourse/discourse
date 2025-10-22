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

    posts =
      Post
        .joins(
          "INNER JOIN discourse_solved_solved_topics ON discourse_solved_solved_topics.answer_post_id = posts.id",
        )
        .joins(:topic)
        .joins("LEFT JOIN categories ON categories.id = topics.category_id")
        .where(user_id: user.id, deleted_at: nil)
        .where(topics: { archetype: Archetype.default, deleted_at: nil })
        .where(
          "topics.category_id IS NULL OR NOT categories.read_restricted OR topics.category_id IN (:secure_category_ids)",
          secure_category_ids: guardian.secure_category_ids,
        )
        .includes(:user, topic: %i[category tags])
        .order("discourse_solved_solved_topics.created_at DESC")
        .offset(offset)
        .limit(limit)

    render_serialized(posts, DiscourseSolved::SolvedPostSerializer, root: "user_solved_posts")
  end
end
