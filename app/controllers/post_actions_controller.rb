require_dependency 'discourse'

class PostActionsController < ApplicationController

  before_filter :ensure_logged_in, except: :users
  before_filter :fetch_post_from_params
  before_filter :fetch_post_action_type_id_from_params

  def create
    taken = PostAction.counts_for([@post], current_user)[@post.id]
    guardian.ensure_post_can_act!(@post, PostActionType.types[@post_action_type_id], taken_actions: taken)

    args = {}
    args[:message] = params[:message] if params[:message].present?
    args[:take_action] = true if guardian.is_staff? && params[:take_action] == 'true'
    args[:flag_topic] = true if params[:flag_topic] == 'true'

    post_action = PostAction.act(current_user, @post, @post_action_type_id, args)

    if post_action.blank? || post_action.errors.present?
      render_json_error(post_action)
    else
      # We need to reload or otherwise we are showing the old values on the front end
      @post.reload
      render_post_json(@post, _add_raw = false)
    end
  end

  def users
    guardian.ensure_can_see_post_actors!(@post.topic, @post_action_type_id)

    post_actions = @post.post_actions.where(post_action_type_id: @post_action_type_id)
                        .includes(:user)
                        .order('post_actions.created_at asc')

    render_serialized(post_actions.to_a, PostActionUserSerializer)
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
      guardian.ensure_can_see!(@post)
    end

    def fetch_post_action_type_id_from_params
      params.require(:post_action_type_id)
      @post_action_type_id = params[:post_action_type_id].to_i
    end
end
