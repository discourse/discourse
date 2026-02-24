# frozen_string_literal: true

class DiscourseSolved::AnswerController < ::ApplicationController
  requires_plugin DiscourseSolved::PLUGIN_NAME

  before_action :limit_accepts

  def accept
    DiscourseSolved::AcceptAnswer.call(params: { post_id: params[:id] }, guardian:) do
      on_success { |topic:| render_json_dump(topic.accepted_answer_post_info) }
      on_model_not_found(:post) { raise Discourse::NotFound }
      on_model_not_found(:topic) { raise Discourse::NotFound }
      on_failed_policy(:can_accept_answer) { raise Discourse::InvalidAccess }
      on_model_errors(:solved) do |model|
        render_json_error(model, type: :record_invalid, status: 422)
      end
      on_failed_contract do |contract|
        render json: failed_json.merge(errors: contract.errors.full_messages), status: :bad_request
      end
      on_failure { render json: failed_json, status: :unprocessable_entity }
    end
  end

  def unaccept
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

  private

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
