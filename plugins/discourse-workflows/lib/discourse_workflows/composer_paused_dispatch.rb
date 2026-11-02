# frozen_string_literal: true

module DiscourseWorkflows
  # Fires the composer paused triggers a draft matches, each phrase once per claim scope.
  module ComposerPausedDispatch
    def self.published_triggers(fire_on)
      trigger_class = Nodes::ComposerPaused::V1

      WorkflowDependency
        .cached_published_triggers(trigger_class.identifier)
        .select do |published_trigger|
          trigger_class.fires_on?(NodeData.parameters(published_trigger.trigger_node), fire_on)
        end
    end

    # Returns false when the rate limit ran out before every matching trigger fired. It counts
    # workflow runs, since one pause can fire several workflows.
    def self.call(published_triggers, snapshot, claim_scope)
      trigger_class = Nodes::ComposerPaused::V1
      rate_limiter = ComposerPausedClaims.rate_limiter(snapshot.user)

      published_triggers.all? do |published_trigger|
        parameters = NodeData.parameters(published_trigger.trigger_node)
        next true if !trigger_class.matches_snapshot?(parameters, snapshot)

        phrases = trigger_class.phrases(parameters)
        if phrases.any?
          unclaimed = ComposerPausedClaims.unclaimed(claim_scope, published_trigger, phrases)
          phrases = trigger_class.matched_phrases(unclaimed, snapshot.own_text)
          next true if phrases.empty?
        end

        next false if !rate_limiter.can_perform?

        phrases = ComposerPausedClaims.claim(claim_scope, published_trigger, phrases)
        next true if phrases.nil?

        if !rate_limiter.performed!(raise_error: false)
          ComposerPausedClaims.release(claim_scope, published_trigger, phrases)
          next false
        end

        TriggerDispatcher.enqueue(
          published_trigger,
          trigger_data: trigger_class.new(snapshot, phrases).output,
          user_id: snapshot.user.id,
        )
        true
      rescue => e
        Rails.logger.error(
          "discourse-workflows: trigger:composer_paused failed " \
            "for workflow #{published_trigger.workflow_id}: #{e.message}",
        )
        true
      end
    end
  end
end
