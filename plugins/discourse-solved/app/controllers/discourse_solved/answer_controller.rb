# frozen_string_literal: true

class DiscourseSolved::AnswerController < ::ApplicationController
  requires_plugin DiscourseSolved::PLUGIN_NAME

  def accept
    limit_accepts

    post = Post.find(params[:id].to_i)

    topic = post.topic
    topic ||= Topic.with_deleted.find(post.topic_id) if guardian.is_staff?

    guardian.ensure_can_accept_answer!(topic, post)

    DiscourseSolved::AcceptAnswer.call(params: { post_id: post.id }, acting_user: current_user) do
      on_success { |accepted_answer:| render_json_dump(accepted_answer) }
      on_model_not_found(:post) { raise Discourse::NotFound }
      on_model_not_found(:topic) { raise Discourse::NotFound }
      on_failed_contract do |contract|
        render json: failed_json.merge(errors: contract.errors.full_messages), status: :bad_request
      end
      on_failure { render json: failed_json, status: :unprocessable_entity }
    end
  end

  def unaccept
    limit_accepts

    post = Post.find(params[:id].to_i)

    topic = post.topic
    topic ||= Topic.with_deleted.find(post.topic_id) if guardian.is_staff?

    guardian.ensure_can_accept_answer!(topic, post)

    DiscourseSolved::UnacceptAnswer.call(params: { post_id: post.id }) do
      on_success { render json: success_json }
      on_model_not_found(:post) { raise Discourse::NotFound }
      on_model_not_found(:topic) { raise Discourse::NotFound }
      on_failed_contract do |contract|
        render json: failed_json.merge(errors: contract.errors.full_messages), status: :bad_request
      end
      on_failure { render json: failed_json, status: :unprocessable_entity }
    end
  end

  def limit_accepts
    return if current_user.staff?
    run_rate_limiter =
      DiscoursePluginRegistry.apply_modifier(
        :solved_answers_controller_run_rate_limiter,
        true,
        current_user,
      )
    return if !run_rate_limiter
    RateLimiter.new(nil, "accept-hr-#{current_user.id}", 20, 1.hour).performed!
    RateLimiter.new(nil, "accept-min-#{current_user.id}", 4, 30.seconds).performed!
  end
end
