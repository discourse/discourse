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

    # The rate limit counts workflow runs, since one pause can fire several workflows.
    def self.call(published_triggers, snapshot, claim_scope)
      trigger_class = Nodes::ComposerPaused::V1
      rate_limiter = ComposerPausedClaims.rate_limiter(snapshot.user)

      published_triggers.each do |published_trigger|
        break if !rate_limiter.can_perform?

        parameters = NodeData.parameters(published_trigger.trigger_node)
        next if !trigger_class.matches_snapshot?(parameters, snapshot)

        phrases = trigger_class.phrases(parameters)
        if phrases.any?
          unclaimed = ComposerPausedClaims.unclaimed(claim_scope, published_trigger, phrases)
          phrases = trigger_class.matched_phrases(unclaimed, snapshot.own_text)
          next if phrases.empty?
        end

        phrases = ComposerPausedClaims.claim(claim_scope, published_trigger, phrases)
        next if phrases.nil? || !rate_limiter.performed!(raise_error: false)

        TriggerDispatcher.enqueue(
          published_trigger,
          trigger_data: trigger_class.new(snapshot, phrases).output,
          user_id: snapshot.user.id,
        )
      rescue => e
        Rails.logger.error(
          "discourse-workflows: trigger:composer_paused failed " \
            "for workflow #{published_trigger.workflow_id}: #{e.message}",
        )
      end
    end
  end
end
