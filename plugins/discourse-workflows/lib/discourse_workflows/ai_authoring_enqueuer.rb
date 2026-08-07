# frozen_string_literal: true

module DiscourseWorkflows
  class AiAuthoringEnqueuer
    def self.enabled?
      SiteSetting.enable_discourse_workflows &&
        SiteSetting.discourse_workflows_ai_authoring_enabled && defined?(DiscourseAi).present?
    end

    def self.enqueue(session:, generation_id:, user:)
      return if !enabled?

      session.update!(status: "generating")
      Ai::ProgressPublisher.publish(
        generation_id: generation_id,
        user: user,
        status: "progress",
        stage: "queued",
        message: I18n.t("discourse_workflows.ai.progress.queued"),
      )

      Jobs.enqueue(
        Jobs::DiscourseWorkflows::AuthorWithAi,
        session_id: session.id,
        user_id: user.id,
        generation_id: generation_id,
      )
    end
  end
end
