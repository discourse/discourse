# frozen_string_literal: true

class PostActionsController < ApplicationController
  requires_login

  before_action :fetch_post_from_params
  before_action :fetch_post_action_type_id_from_params

  def create
    raise Discourse::NotFound if @post.blank?

    creator = PostActionCreator.new(
      current_user,
      @post,
      @post_action_type_id,
      is_warning: params[:is_warning],
      message: params[:message],
      take_action: params[:take_action] == 'true',
      flag_topic: params[:flag_topic] == 'true'
    )
    result = creator.perform

    if result.failed?
      render_json_error(result)
    else
      # We need to reload or otherwise we are showing the old values on the front end
      @post.reload

      if @post_action_type_id == PostActionType.types[:like]
        limiter = result.post_action.post_action_rate_limiter
        response.headers['Discourse-Actions-Remaining'] = limiter.remaining.to_s
        response.headers['Discourse-Actions-Max'] = limiter.max.to_s
      end
      render_post_json(@post, add_raw: false)
    end
  end

  def destroy
    result = PostActionDestroyer.new(
      current_user,
      Post.find_by(id: params[:id].to_i),
      @post_action_type_id
    ).perform

    if result.failed?
      render_json_error(result)
    else
      render_post_json(result.post, add_raw: false)
    end
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
