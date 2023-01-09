# frozen_string_literal: true

class DiscoursePoll::PollsController < ::ApplicationController
  requires_plugin DiscoursePoll::PLUGIN_NAME

  before_action :ensure_logged_in, except: %i[voters grouped_poll_results]

  def vote
    post_id = params.require(:post_id)
    poll_name = params.require(:poll_name)
    options = params.require(:options)

    begin
      poll, options = DiscoursePoll::Poll.vote(current_user, post_id, poll_name, options)
      render json: { poll: poll, vote: options }
    rescue DiscoursePoll::Error => e
      render_json_error e.message
    end
  end

  def remove_vote
    post_id = params.require(:post_id)
    poll_name = params.require(:poll_name)

    begin
      poll = DiscoursePoll::Poll.remove_vote(current_user, post_id, poll_name)
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
      poll = DiscoursePoll::Poll.toggle_status(current_user, post_id, poll_name, status)
      render json: { poll: poll }
    rescue DiscoursePoll::Error => e
      render_json_error e.message
    end
  end

  def voters
    post_id = params.require(:post_id)
    poll_name = params.require(:poll_name)
    opts = params.permit(:limit, :page, :option_id)

    raise Discourse::InvalidParameters.new(:post_id) if !Post.where(id: post_id).exists?

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
               grouped_results:
                 DiscoursePoll::Poll.grouped_poll_results(
                   current_user,
                   post_id,
                   poll_name,
                   user_field_name,
                 ),
             }
    rescue DiscoursePoll::Error => e
      render_json_error e.message
    end
  end
end
