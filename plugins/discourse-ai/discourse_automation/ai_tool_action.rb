# frozen_string_literal: true

if defined?(DiscourseAutomation)
  DiscourseAutomation::Scriptable.add("ai_tool_action") do
    version 1
    run_in_background

    triggerables %i[post_created_edited]

    # Select which AI tool to run
    field :tool,
          component: :choices,
          required: true,
          extra: {
            content: DiscourseAi::Automation.available_tools_all,
          }

    # Optional LLM for tools that call llm.generate()
    field :llm_model,
          component: :choices,
          extra: {
            content: DiscourseAi::Automation.available_models,
          }

    script do |context, fields, automation|
      tool_id = fields.dig("tool", "value")
      post = context["post"]
      next if post&.user&.bot?

      begin
        RateLimiter.new(
          Discourse.system_user,
          "ai_tool_action_#{post.id}",
          SiteSetting.ai_automation_max_triage_per_post_per_minute,
          1.minute,
        ).performed!

        RateLimiter.new(
          Discourse.system_user,
          "ai_tool_action",
          SiteSetting.ai_automation_max_triage_per_minute,
          1.minute,
        ).performed!

        DiscourseAi::Automation::AiToolAction.handle(
          post: post,
          tool_id: tool_id,
          llm_model_id: fields.dig("llm_model", "value"),
          automation: automation,
        )
      rescue => e
        Discourse.warn_exception(e, message: "ai_tool_action: failed on post #{post.id}")
        raise e if Rails.env.test?
      end
    end
  end
end
