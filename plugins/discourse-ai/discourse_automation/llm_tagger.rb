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

    field :confidence_threshold, component: :text, default: "70"

    field :max_tags_per_post, component: :text, default: "3"

    field :max_post_tokens, component: :text, default: "4000"

    field :allow_restricted_tags, component: :boolean, default: false

    field :max_posts_for_context, component: :text, default: "5"

    script do |context, fields|
      post = context["post"]
      next if post&.user&.bot?

      next if post.post_number != 1

      next if post.topic.custom_fields["llm_tagger_processed"]

      # Skip if tags were manually edited in the most recent revision
      if post.version > 1
        latest_revision = post.post_revisions.order(:number).last
        next if latest_revision&.modifications&.has_key?("tags")
      end

      tagger_persona_id = fields.dig("tagger_persona", "value")
      tag_mode = fields.dig("tag_mode", "value") || "manual"
      manual_tags = fields.dig("available_tags", "value") || []
      confidence_threshold = fields.dig("confidence_threshold", "value").to_f
      max_tags = fields.dig("max_tags_per_post", "value").to_i
      max_post_tokens = fields.dig("max_post_tokens", "value").to_i
      allow_restricted_tags = fields.dig("allow_restricted_tags", "value") || false
      max_posts_for_context = fields.dig("max_posts_for_context", "value").to_i

      confidence_threshold = 70 if confidence_threshold <= 0
      max_tags = 3 if max_tags <= 0
      max_post_tokens = 4000 if max_post_tokens <= 0
      max_posts_for_context = 5 if max_posts_for_context <= 0

      # Skip if manual mode but no tags configured
      if tag_mode == "manual"
        next if manual_tags.empty?
      end

      begin
        per_post_limiter =
          RateLimiter.new(
            Discourse.system_user,
            "llm_tagger_#{post.id}",
            3, # max 3 per post per minute
            1.minute,
          )

        global_limiter =
          RateLimiter.new(
            Discourse.system_user,
            "llm_tagger",
            30, # max 30 per minute globally
            1.minute,
          )

        # Check if we can perform the action before proceeding
        next unless per_post_limiter.can_perform? && global_limiter.can_perform?

        # Only perform the rate limiting if we're going to proceed
        per_post_limiter.performed!
        global_limiter.performed!

        DiscourseAi::Automation::LlmTagger.handle(
          post: post,
          tagger_persona_id: tagger_persona_id,
          tag_mode: tag_mode,
          available_tags: manual_tags,
          confidence_threshold: confidence_threshold,
          max_tags: max_tags,
          max_post_tokens: max_post_tokens,
          allow_restricted_tags: allow_restricted_tags,
          max_posts_for_context: max_posts_for_context,
          automation: self.automation,
        )

        post.topic.custom_fields["llm_tagger_processed"] = true
        post.topic.save_custom_fields
      rescue => e
        Discourse.warn_exception(
          e,
          message: "llm_tagger: failed to process post #{post.id} #{post.url}",
        )
      end
    end
  end
end
