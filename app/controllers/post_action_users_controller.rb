# frozen_string_literal: true

class PostActionUsersController < ApplicationController
  INDEX_LIMIT = 200

  def index
    params.require(:post_action_type_id)
    params.require(:id)
    post_action_type_id = params[:post_action_type_id].to_i

    page = fetch_int_from_params(:page, default: 0)
    page_size = fetch_limit_from_params(default: INDEX_LIMIT, max: INDEX_LIMIT)

    # Find the post, and then determine if they can see the post (if deleted)
    post = Post.with_deleted.find_by(id: params[:id].to_i)
    guardian.ensure_can_see!(post)

    post_actions =
      post
        .post_actions
        .where(post_action_type_id: post_action_type_id)
        .order("post_actions.created_at ASC, post_actions.id ASC")

    post_actions =
      DiscoursePluginRegistry.apply_modifier(:post_action_users_list, post_actions, post)

    can_see_actors = guardian.can_see_post_actors?(post.topic, post_action_type_id)

    if !can_see_actors
      raise Discourse::InvalidAccess if current_user.blank?
      post_actions = post_actions.where(user_id: current_user.id)
    end

    total_count = post_actions.count if can_see_actors
    post_actions = post_actions.includes(:user).offset(page * page_size).limit(page_size).to_a
    data = {
      post_action_users:
        serialize_data(
          post_actions,
          PostActionUserSerializer,
          unknown_user_ids: current_user_muting_or_ignoring_users(post_actions.map(&:user_id)),
        ),
    }

    if can_see_actors && total_count > page_size
      data[:total_rows_post_action_users] = total_count

      if total_count > ((page + 1) * page_size)
        data[:load_more_post_action_users] = post_action_users_path(
          id: post.id,
          post_action_type_id: post_action_type_id,
          page: page + 1,
          limit: page_size,
        )
      end
    end

    render_json_dump(data)
  end

  private

  def current_user_muting_or_ignoring_users(user_ids)
    return [] if current_user.blank?
    UserCommScreener.new(
      acting_user: current_user,
      target_user_ids: user_ids,
    ).actor_ignoring_or_muting_users
  end
end
