# frozen_string_literal: true

if defined?(DiscourseAutomation)
  DiscourseAutomation::Scriptable.add("llm_tagger") do
    version 1
    run_in_background

    placeholder :post

    triggerables %i[post_created_edited]

    field :tagger_persona,
          component: :choices,
          required: true,
          extra: {
            content:
              DiscourseAi::Automation.available_persona_choices(
                require_user: false,
                require_default_llm: true,
              ),
          }

    field :tag_mode,
          component: :choices,
          required: true,
          default: "manual",
          extra: {
            content: [
              {
                id: "manual",
                name: "js.discourse_automation.scriptables.llm_tagger.tag_mode.manual",
              },
              {
                id: "discover",
                name: "js.discourse_automation.scriptables.llm_tagger.tag_mode.discover",
              },
            ],
          }

    # Available tags only used when tag_mode is "manual"
    field :available_tags, component: :tags, required: false

    field :confidence_threshold, component: :text, default: "0.7"

    field :max_tags_per_post, component: :text, default: "3"

    field :max_post_tokens, component: :text, default: "4000"

    script do |context, fields|
      post = context["post"]
      next if post&.user&.bot?

      next if post.post_number != 1

      next if post.custom_fields["llm_tagger_processed"]

      tagger_persona_id = fields.dig("tagger_persona", "value")
      tag_mode = fields.dig("tag_mode", "value") || "manual"
      manual_tags = fields.dig("available_tags", "value") || []
      confidence_threshold = fields.dig("confidence_threshold", "value").to_f
      max_tags = fields.dig("max_tags_per_post", "value").to_i
      max_post_tokens = fields.dig("max_post_tokens", "value").to_i

      confidence_threshold = 0.7 if confidence_threshold <= 0
      max_tags = 3 if max_tags <= 0
      max_post_tokens = 4000 if max_post_tokens <= 0

      # Skip if manual mode but no tags configured
      if tag_mode == "manual"
        next if manual_tags.empty?
      end

      begin
        RateLimiter.new(
          Discourse.system_user,
          "llm_tagger_#{post.id}",
          3, # max 3 per post per minute
          1.minute,
        ).performed!

        RateLimiter.new(
          Discourse.system_user,
          "llm_tagger",
          30, # max 30 per minute globally
          1.minute,
        ).performed!

        DiscourseAi::Automation::LlmTagger.handle(
          post: post,
          tagger_persona_id: tagger_persona_id,
          tag_mode: tag_mode,
          available_tags: manual_tags,
          confidence_threshold: confidence_threshold,
          max_tags: max_tags,
          max_post_tokens: max_post_tokens,
          automation: self.automation,
        )

        post.custom_fields["llm_tagger_processed"] = true
        post.save_custom_fields
      rescue => e
        Discourse.warn_exception(
          e,
          message: "llm_tagger: failed to process post #{post.id} #{post.url}",
        )
      end
    end
  end
end
