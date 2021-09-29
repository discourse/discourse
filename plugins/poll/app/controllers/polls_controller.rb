# frozen_string_literal: true

class DiscoursePoll::PollsController < ::ApplicationController
  requires_plugin DiscoursePoll::PLUGIN_NAME

  before_action :ensure_logged_in, except: [:voters, :grouped_poll_results]

  def vote
    post_id = params.require(:post_id)
    poll_name = params.require(:poll_name)
    options = params.require(:options)

    begin
      poll, options = DiscoursePoll::Poll.vote(post_id, poll_name, options, current_user)
      render json: { poll: poll, vote: options }
    rescue DiscoursePoll::Error => e
      render_json_error e.message
    end
  end

  def remove_vote
    post_id = params.require(:post_id)
    poll_name = params.require(:poll_name)

    begin
      poll = DiscoursePoll::Poll.remove_vote(post_id, poll_name, current_user)
      render json: { poll: poll }
    rescue DiscoursePoll::Error => e
      render_json_error e.message
    end
  end

  def toggle_status
    post_id = params.require(:post_id)
    poll_name = params.require(:poll_name)
    status = params.require(:status)

    begin
      poll = DiscoursePoll::Poll.toggle_status(post_id, poll_name, status, current_user)
      render json: { poll: poll }
    rescue DiscoursePoll::Error => e
      render_json_error e.message
    end
  end

  def voters
    post_id = params.require(:post_id)
    poll_name = params.require(:poll_name)
    opts = params.permit(:limit, :page, :option_id)

    post = Post.find_by(id: post_id)
    raise Discourse::InvalidParameters.new(:post_id) if !post

    poll = Poll.find_by(post_id: post_id, name: poll_name)
    raise Discourse::InvalidParameters.new(:poll_name) if !poll&.can_see_voters?(current_user)

    render json: { voters: DiscoursePoll::Poll.serialized_voters(poll, opts) }
  end

  def grouped_poll_results
    post_id = params.require(:post_id)
    poll_name = params.require(:poll_name)
    user_field_name = params.require(:user_field_name)

    begin
      render json: {
        grouped_results: DiscoursePoll::Poll.grouped_poll_results(post_id, poll_name, user_field_name, current_user)
      }
    rescue DiscoursePoll::Error => e
      render_json_error e.message
    end
  end
end
