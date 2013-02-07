require_dependency 'discourse'

class PostActionsController < ApplicationController

  before_filter :ensure_logged_in, except: :users
  before_filter :fetch_post_from_params

  def create
    id = params[:post_action_type_id].to_i
    if action = PostActionType.where(id: id).first
      guardian.ensure_post_can_act!(@post, PostActionType.Types.invert[id])
      PostAction.act(current_user, @post, action.id, params[:message])

      # We need to reload or otherwise we are showing the old values on the front end
      @post.reload

      post_serializer = PostSerializer.new(@post, scope: guardian, root: false)
      render_json_dump(post_serializer)
    else
      raise Discourse::InvalidParameters.new(:post_action_type_id)
    end
  end

  def users
    requires_parameter(:post_action_type_id)
    post_action_type_id = params[:post_action_type_id].to_i

    guardian.ensure_can_see_post_actors!(@post.topic, post_action_type_id)

    users = User.
              joins(:post_actions).
              where(["post_actions.post_id = ? and post_actions.post_action_type_id = ? and post_actions.deleted_at IS NULL", @post.id, post_action_type_id]).all

    render_serialized(users, BasicUserSerializer)
  end

  def destroy
    requires_parameter(:post_action_type_id)

    post_action = current_user.post_actions.where(post_id: params[:id].to_i, post_action_type_id: params[:post_action_type_id].to_i, deleted_at: nil).first
    raise Discourse::NotFound if post_action.blank?
    guardian.ensure_can_delete!(post_action)
    PostAction.remove_act(current_user, @post, post_action.post_action_type_id)

    render nothing: true
  end

  def clear_flags
    requires_parameter(:post_action_type_id)
    raise Discourse::InvalidAccess unless guardian.is_admin?

    PostAction.clear_flags!(@post, current_user.id, params[:post_action_type_id].to_i)
    @post.reload

    if @post.is_flagged?
      render json: {success: true, hidden: true}
    else
      @post.unhide!
      render json: {success: true, hidden: false}
    end
  end

  private

    def fetch_post_from_params
      requires_parameter(:id)
      @post = Post.where(id: params[:id]).first
      guardian.ensure_can_see!(@post)
    end
end
