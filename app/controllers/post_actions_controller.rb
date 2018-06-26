require_dependency 'discourse'

class PostActionsController < ApplicationController
  requires_login

  before_action :fetch_post_from_params
  before_action :fetch_post_action_type_id_from_params

  def create
    raise Discourse::NotFound if @post.blank?

    taken = PostAction.counts_for([@post], current_user)[@post.id]

    guardian.ensure_post_can_act!(
      @post,
      PostActionType.types[@post_action_type_id],
      opts: {
        is_warning: params[:is_warning],
        taken_actions: taken
      }
    )

    args = {}
    args[:message] = params[:message] if params[:message].present?
    args[:is_warning] = params[:is_warning] if params[:is_warning].present? && guardian.is_staff?
    args[:take_action] = true if guardian.is_staff? && params[:take_action] == 'true'
    args[:flag_topic] = true if params[:flag_topic] == 'true'

    begin
      post_action = PostAction.act(current_user, @post, @post_action_type_id, args)
    rescue PostAction::FailedToCreatePost => e
      return render_json_error(e.message)
    end

    if post_action.blank? || post_action.errors.present?
      render_json_error(post_action)
    else
      # We need to reload or otherwise we are showing the old values on the front end
      @post.reload

      if @post_action_type_id == PostActionType.types[:like]
        limiter = post_action.post_action_rate_limiter
        response.headers['Discourse-Actions-Remaining'] = limiter.remaining.to_s
        response.headers['Discourse-Actions-Max'] = limiter.max.to_s
      end
      render_post_json(@post, _add_raw = false)
    end
  end

  def destroy
    post_action = current_user.post_actions.find_by(post_id: params[:id].to_i, post_action_type_id: @post_action_type_id, deleted_at: nil)
    raise Discourse::NotFound if post_action.blank?

    guardian.ensure_can_delete!(post_action)

    PostAction.remove_act(current_user, @post, post_action.post_action_type_id)

    @post.reload
    render_post_json(@post, _add_raw = false)
  end

  def defer_flags
    guardian.ensure_can_defer_flags!(@post)

    PostAction.defer_flags!(@post, current_user)

    render json: { success: true }
  end

  private

  def fetch_post_from_params
    params.require(:id)

    flag_topic = params[:flag_topic]
    flag_topic = flag_topic && (flag_topic == true || flag_topic == "true")

    post_id = if flag_topic
      begin
        Topic.find(params[:id]).posts.first.id
      rescue
        raise Discourse::NotFound
      end
    else
      params[:id]
    end

    finder = Post.where(id: post_id)

    # Include deleted posts if the user is a staff
    finder = finder.with_deleted if guardian.is_staff?

    @post = finder.first
  end

  def fetch_post_action_type_id_from_params
    params.require(:post_action_type_id)
    @post_action_type_id = params[:post_action_type_id].to_i
  end
end
