# frozen_string_literal: true

class PostActionUsersController < ApplicationController
  def index
    params.require(:post_action_type_id)
    params.require(:id)
    post_action_type_id = params[:post_action_type_id].to_i

    page = params[:page].to_i
    page_size = (params[:limit] || 200).to_i

    finder = Post.where(id: params[:id].to_i)
    finder = finder.with_deleted if guardian.is_staff?

    post = finder.first
    guardian.ensure_can_see!(post)

    unknown_user_ids = Set.new
    if current_user.present?
      result = DB.query_single(<<~SQL, user_id: current_user.id)
        SELECT mu.muted_user_id AS id FROM muted_users AS mu WHERE mu.user_id = :user_id
        UNION
        SELECT iu.ignored_user_id AS id FROM ignored_users AS iu WHERE iu.user_id = :user_id
      SQL
      unknown_user_ids.merge(result)
    end

    post_actions = post.post_actions.where(post_action_type_id: post_action_type_id)
      .includes(:user)
      .offset(page * page_size)
      .order('post_actions.created_at ASC')
      .limit(page_size)

    if !guardian.can_see_post_actors?(post.topic, post_action_type_id)
      raise Discourse::InvalidAccess unless current_user
      post_actions = post_actions.where(user_id: current_user.id)
    end

    action_type = PostActionType.types.key(post_action_type_id)
    total_count = post["#{action_type}_count"].to_i

    data = {
      post_action_users: serialize_data(
        post_actions.to_a,
        PostActionUserSerializer,
        unknown_user_ids: unknown_user_ids
      )
    }

    if total_count > page_size
      data[:total_rows_post_action_users] = total_count
    end

    render_json_dump(data)
  end
end
