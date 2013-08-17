require_dependency 'discourse'

class PostActionsController < ApplicationController

  before_filter :ensure_logged_in, except: :users
  before_filter :fetch_post_from_params
  before_filter :fetch_post_action_type_id_from_params

  def create
    guardian.ensure_post_can_act!(@post, PostActionType.types[@post_action_type_id])

    args = {}
    args[:message] = params[:message] if params[:message].present?
    args[:take_action] = true if guardian.is_staff? and params[:take_action] == 'true'

    post_action = PostAction.act(current_user, @post, @post_action_type_id, args)

    if post_action.blank? || post_action.errors.present?
      render_json_error(post_action)
    else
      # We need to reload or otherwise we are showing the old values on the front end
      @post.reload
      post_serializer = PostSerializer.new(@post, scope: guardian, root: false)
      render_json_dump(post_serializer)
    end
  end

  def users
    guardian.ensure_can_see_post_actors!(@post.topic, @post_action_type_id)

    post_actions = @post.post_actions.where(post_action_type_id: @post_action_type_id).includes(:user)

    render_serialized(post_actions.to_a, PostActionUserSerializer)
  end

  def destroy
    post_action = current_user.post_actions.where(post_id: params[:id].to_i, post_action_type_id: @post_action_type_id, deleted_at: nil).first

    raise Discourse::NotFound if post_action.blank?

    guardian.ensure_can_delete!(post_action)

    PostAction.remove_act(current_user, @post, post_action.post_action_type_id)

    render nothing: true
  end

  def clear_flags
    guardian.ensure_can_clear_flags!(@post)

    PostAction.clear_flags!(@post, current_user.id, @post_action_type_id)
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
      params.require(:id)
      finder = Post.where(id: params[:id])

      # Include deleted posts if the user is a moderator (to guardian ?)
      finder = finder.with_deleted if current_user.try(:moderator?)

      @post = finder.first
      guardian.ensure_can_see!(@post)
    end

    def fetch_post_action_type_id_from_params
      params.require(:post_action_type_id)
      @post_action_type_id = params[:post_action_type_id].to_i
    end
end
