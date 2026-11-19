# frozen_string_literal: true

module DiscourseWorkflows
  module PostButtonFeedback
    TTL = 1.hour.to_i

    def self.remember(job_id, feedback)
      return if job_id.blank?

      Discourse.redis.set(key(job_id), feedback.to_json, ex: TTL, nx: true)
    rescue => error
      Discourse.warn_exception(
        error,
        message: "discourse-workflows: could not store post button feedback",
      )
    end

    def self.finish(job_id, status)
      return if job_id.blank?

      payload = Discourse.redis.getdel(key(job_id))
      return if payload.blank?

      user_id, client_id, request_id =
        JSON.parse(payload).values_at("user_id", "client_id", "request_id")
      MessageBus.publish(
        "/discourse-workflows/post-button/#{user_id}/#{request_id}",
        { status: },
        user_ids: [user_id],
        client_ids: [client_id],
        max_backlog_size: 1,
        max_backlog_age: TTL,
      )
    rescue => error
      Discourse.warn_exception(error, message: "discourse-workflows: post button feedback failed")
    end

    def self.key(job_id)
      "discourse_workflows:post_button_feedback:#{job_id}"
    end
    private_class_method :key
  end
end
