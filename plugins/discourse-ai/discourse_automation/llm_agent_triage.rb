# frozen_string_literal: true

if defined?(DiscourseAutomation)
  DiscourseAutomation::Scriptable.add("llm_agent_triage") do
    version 1
    run_in_background

    triggerables %i[post_created_edited stalled_topic]

    field :agent,
          component: :choices,
          required: true,
          extra: {
            content: DiscourseAi::Automation.available_agent_choices,
          }
    field :whisper, component: :boolean
    field :silent_mode, component: :boolean

    script do |context, fields|
      post = context["post"]
      post ||= context["topic"]&.posts&.find_by(post_number: 1)
      next if post.blank?
      next if post.user&.bot?

      agent_id = fields.dig("agent", "value")
      whisper = !!fields.dig("whisper", "value")
      silent_mode = !!fields.dig("silent_mode", "value")

      begin
        RateLimiter.new(
          Discourse.system_user,
          "llm_agent_triage_#{post.id}",
          SiteSetting.ai_automation_max_triage_per_post_per_minute,
          1.minute,
        ).performed!

        RateLimiter.new(
          Discourse.system_user,
          "llm_agent_triage",
          SiteSetting.ai_automation_max_triage_per_minute,
          1.minute,
        ).performed!

        DiscourseAi::Automation::LlmAgentTriage.handle(
          post: post,
          agent_id: agent_id,
          whisper: whisper,
          automation: self.automation,
          silent_mode: silent_mode,
          action: context["action"],
        )
      rescue => e
        Discourse.warn_exception(e, message: "llm_agent_triage: skipped triage on post #{post.id}")
        raise e if Rails.env.tests?
      end
    end
  end
end
