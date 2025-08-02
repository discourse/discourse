# frozen_string_literal: true

class PostActionUsersController < ApplicationController
  INDEX_LIMIT = 200

  def index
    params.require(:post_action_type_id)
    params.require(:id)
    post_action_type_id = params[:post_action_type_id].to_i

    page = params[:page].to_i
    page_size = fetch_limit_from_params(default: INDEX_LIMIT, max: INDEX_LIMIT)

    # Find the post, and then determine if they can see the post (if deleted)
    post = Post.with_deleted.find_by(id: params[:id].to_i)
    guardian.ensure_can_see!(post)

    post_actions =
      post
        .post_actions
        .where(post_action_type_id: post_action_type_id)
        .includes(:user)
        .offset(page * page_size)
        .order("post_actions.created_at ASC")
        .limit(page_size)

    post_actions =
      DiscoursePluginRegistry.apply_modifier(:post_action_users_list, post_actions, post)

    if !guardian.can_see_post_actors?(post.topic, post_action_type_id)
      raise Discourse::InvalidAccess if current_user.blank?
      post_actions = post_actions.where(user_id: current_user.id)
    end

    action_type = PostActionType.types.key(post_action_type_id)
    total_count = post["#{action_type}_count"].to_i
    post_actions = post_actions.to_a
    data = {
      post_action_users:
        serialize_data(
          post_actions,
          PostActionUserSerializer,
          unknown_user_ids: current_user_muting_or_ignoring_users(post_actions.map(&:user_id)),
        ),
    }

    data[:total_rows_post_action_users] = total_count if total_count > page_size

    render_json_dump(data)
  end

  private

  def current_user_muting_or_ignoring_users(user_ids)
    return [] if current_user.blank?
    UserCommScreener.new(
      acting_user: current_user,
      target_user_ids: user_ids,
    ).actor_preventing_communication
  end
end
