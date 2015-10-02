require_dependency 'discourse'

class PostActionUsersController < ApplicationController
  def index
    params.require(:post_action_type_id)
    params.require(:id)
    post_action_type_id = params[:post_action_type_id].to_i

    finder = Post.where(id: params[:id].to_i)
    finder = finder.with_deleted if guardian.is_staff?

    post = finder.first
    guardian.ensure_can_see!(post)
    guardian.ensure_can_see_post_actors!(post.topic, post_action_type_id)

    post_actions = post.post_actions.where(post_action_type_id: post_action_type_id)
                       .includes(:user)
                       .order('post_actions.created_at asc')

    render_serialized(post_actions.to_a, PostActionUserSerializer, root: 'post_action_users')
  end
end
