# frozen_string_literal: true

if defined?(DiscourseAutomation)
  DiscourseAutomation::Scriptable.add("llm_triage") do
    version 1
    run_in_background

    placeholder :post

    triggerables %i[post_created_edited]

    # TODO move to triggerables
    field :include_personal_messages, component: :boolean

    # Inputs
    field :triage_persona,
          component: :choices,
          required: true,
          extra: {
            content:
              DiscourseAi::Automation.available_persona_choices(
                require_user: false,
                require_default_llm: true,
              ),
          }
    field :search_for_text, component: :text, required: true
    field :max_post_tokens, component: :text
    field :stop_sequences, component: :text_list, required: false
    field :max_output_tokens, component: :text

    # Actions
    field :category, component: :category
    field :tags, component: :tags
    field :hide_topic, component: :boolean
    field :flag_post, component: :boolean
    field :flag_type,
          component: :choices,
          required: false,
          extra: {
            content: DiscourseAi::Automation.flag_types,
          },
          default: "review"
    field :canned_reply_user, component: :user
    field :canned_reply, component: :message
    field :reply_persona,
          component: :choices,
          extra: {
            content:
              DiscourseAi::Automation.available_persona_choices(
                require_user: false,
                require_default_llm: true,
              ),
          }
    field :whisper, component: :boolean
    field :notify_author_pm, component: :boolean
    field :notify_author_pm_user, component: :user
    field :notify_author_pm_message, component: :message

    script do |context, fields|
      post = context["post"]
      next if post&.user&.bot?

      if post.topic.private_message?
        include_personal_messages = fields.dig("include_personal_messages", "value")
        next if !include_personal_messages
      end

      triage_persona_id = fields.dig("triage_persona", "value")

      canned_reply = fields.dig("canned_reply", "value")
      canned_reply_user = fields.dig("canned_reply_user", "value")
      reply_persona_id = fields.dig("reply_persona", "value")
      whisper = fields.dig("whisper", "value")
      notify_author_pm = fields.dig("notify_author_pm", "value")
      notify_author_pm_user = fields.dig("notify_author_pm_user", "value")
      notify_author_pm_message = fields.dig("notify_author_pm_message", "value")

      # nothing to do if we already replied
      next if post.user.username == canned_reply_user
      next if post.raw.strip == canned_reply.to_s.strip

      search_for_text = fields.dig("search_for_text", "value")

      category_id = fields.dig("category", "value")
      tags = fields.dig("tags", "value")
      hide_topic = fields.dig("hide_topic", "value")
      flag_post = fields.dig("flag_post", "value")
      flag_type = fields.dig("flag_type", "value")
      max_post_tokens = fields.dig("max_post_tokens", "value").to_i

      max_output_tokens = fields.dig("max_output_tokens", "value").to_i
      max_output_tokens = nil if max_output_tokens <= 0

      max_post_tokens = nil if max_post_tokens <= 0

      stop_sequences = fields.dig("stop_sequences", "value")

      begin
        RateLimiter.new(
          Discourse.system_user,
          "llm_triage_#{post.id}",
          SiteSetting.ai_automation_max_triage_per_post_per_minute,
          1.minute,
        ).performed!

        RateLimiter.new(
          Discourse.system_user,
          "llm_triage",
          SiteSetting.ai_automation_max_triage_per_minute,
          1.minute,
        ).performed!

        DiscourseAi::Automation::LlmTriage.handle(
          post: post,
          triage_persona_id: triage_persona_id,
          search_for_text: search_for_text,
          category_id: category_id,
          tags: tags,
          canned_reply: canned_reply,
          canned_reply_user: canned_reply_user,
          reply_persona_id: reply_persona_id,
          whisper: whisper,
          hide_topic: hide_topic,
          flag_post: flag_post,
          flag_type: flag_type.to_s.to_sym,
          max_post_tokens: max_post_tokens,
          stop_sequences: stop_sequences,
          automation: self.automation,
          max_output_tokens: max_output_tokens,
          action: context["action"],
          notify_author_pm: notify_author_pm,
          notify_author_pm_user: notify_author_pm_user,
          notify_author_pm_message: notify_author_pm_message,
        )
      rescue => e
        Discourse.warn_exception(
          e,
          message: "llm_triage: skipped triage on post #{post.id} #{post.url}",
        )
      end
    end
  end
end
