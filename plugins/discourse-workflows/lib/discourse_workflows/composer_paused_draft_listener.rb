# frozen_string_literal: true

module DiscourseWorkflows
  # Fires composer paused triggers set to the draft autosave. Matching happens here, so their
  # phrases never reach the browser.
  class ComposerPausedDraftListener
    def self.handle(user, draft_key, data)
      return if !SiteSetting.enable_discourse_workflows

      published_triggers = draft_saved_triggers
      return if published_triggers.empty?

      # Autosaves are frequent, so matching must not hold up the request.
      Scheduler::Defer.later("discourse_workflows_composer_paused", current_user: user.id) do
        snapshot = ComposerSnapshot.from_draft(user, draft_key, data)
        new(snapshot).dispatch(published_triggers) if snapshot
      end
    rescue => e
      Rails.logger.error("discourse-workflows: trigger:composer_paused failed: #{e.message}")
    end

    def self.draft_saved_triggers
      trigger_class = Nodes::ComposerPaused::V1

      WorkflowDependency
        .cached_published_triggers(trigger_class.identifier)
        .select do |published_trigger|
          trigger_class.fires_on?(
            NodeData.parameters(published_trigger.trigger_node),
            trigger_class::DRAFT_SAVED,
          )
        end
    end

    def initialize(snapshot)
      @snapshot = snapshot
    end

    def dispatch(published_triggers)
      trigger_class = Nodes::ComposerPaused::V1
      rate_limiter = ComposerPausedClaims.rate_limiter(@snapshot.user)

      published_triggers.each do |published_trigger|
        parameters = NodeData.parameters(published_trigger.trigger_node)
        next if !trigger_class.matches_snapshot?(parameters, @snapshot)

        phrases = trigger_class.matched_phrases(parameters, @snapshot.own_text)
        next if trigger_class.phrases(parameters).any? && phrases.empty?
        next if draft_id.nil? || !rate_limiter.can_perform?

        phrases = ComposerPausedClaims.claim("draft:#{draft_id}", published_trigger, phrases)
        next if phrases.nil? || !rate_limiter.performed!(raise_error: false)

        TriggerDispatcher.enqueue(
          published_trigger,
          trigger_data: trigger_class.new(@snapshot, phrases).output,
          user_id: @snapshot.user.id,
        )
      rescue => e
        Rails.logger.error(
          "discourse-workflows: trigger:composer_paused failed " \
            "for workflow #{published_trigger.workflow_id}: #{e.message}",
        )
      end
    end

    private

    # A cleared draft is re-created with a new id, so the next post starts over.
    def draft_id
      return @draft_id if defined?(@draft_id)

      @draft_id =
        ::Draft.where(user_id: @snapshot.user.id, draft_key: @snapshot.draft_key).pick(:id)
    end
  end
end
