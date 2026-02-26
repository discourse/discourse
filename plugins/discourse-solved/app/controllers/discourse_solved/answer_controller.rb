# frozen_string_literal: true

class DiscourseSolved::AnswerController < ::ApplicationController
  requires_plugin DiscourseSolved::PLUGIN_NAME

  before_action :limit_accepts

  def accept
    DiscourseSolved::Answer::Accept.call(params: { post_id: params[:id] }, guardian:) do |result|
      on_success { |topic:| render_json_dump(topic.accepted_answer_post_info) }
      on_failure { render(json: failed_json, status: :unprocessable_entity) }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: :bad_request)
      end
      on_model_not_found(:post) { raise Discourse::NotFound }
      on_model_not_found(:topic) { raise Discourse::NotFound }
      on_failed_policy(:can_accept_answer) { raise Discourse::InvalidAccess }
    end
  end

  def unaccept
    post = Post.find(params[:id].to_i)

    topic = post.topic
    topic ||= Topic.with_deleted.find(post.topic_id) if guardian.is_staff?

    guardian.ensure_can_accept_answer!(topic, post)

    DiscourseSolved.unaccept_answer!(post, topic: topic)

    render json: success_json
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
