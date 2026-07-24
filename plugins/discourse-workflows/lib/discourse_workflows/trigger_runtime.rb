# frozen_string_literal: true

module DiscourseWorkflows
  class TriggerRuntime
    class << self
      def tick!(now: Time.current.utc)
        now = scheduled_minute(now)

        published_triggers("trigger:schedule").each do |published_trigger|
          run_trigger(published_trigger, mode: :normal, activation_mode: :trigger, now:, tick: true)
        end
      end

      def activate_workflow!(workflow, workflow_version: workflow.active_version)
        return if workflow_version.nil?

        Webhook::Action::ActivateWebhooks.call(
          workflow: workflow,
          workflow_version: workflow_version,
        )

        activation_trigger_nodes(workflow_version).each do |node|
          published_trigger = PublishedTrigger.new(workflow:, workflow_version:, trigger_node: node)
          run_trigger(
            published_trigger,
            mode: :normal,
            activation_mode: :init,
            tick: false,
            dispatch: :none,
          )
        end
      end

      def deactivate_workflow!(workflow)
        Webhook::Action::DeactivateWebhooks.call(workflow: workflow)
      end

      def manual_payload_for(workflow:, trigger_node:, user:)
        return {} if trigger_node["type"] == "trigger:manual"

        node_type_class = node_type_for(trigger_node)
        if node_type_class.respond_to?(:trigger_data_for)
          return node_type_class.trigger_data_for(TriggerNodeContext.new(trigger_node))
        end
        return {} unless node_type_class&.capability_enabled?(:synthesizes_manual_data)

        manual_trigger_data(workflow:, trigger_node:, user:)
      end

      def manual_trigger_data(workflow:, trigger_node:, user:)
        workflow_version = workflow.workflow_versions.find_by(version_id: workflow.version_id)
        node_type_class = node_type_for(trigger_node)
        return {} unless node_type_class&.capability_enabled?(:synthesizes_manual_data)

        published_trigger =
          PublishedTrigger.new(workflow:, workflow_version:, trigger_node: trigger_node)
        runtime_state = runtime_state_for(published_trigger)
        ctx =
          Executor::TriggerExecutionContext.new(
            published_trigger:,
            mode: :manual,
            activation_mode: :manual,
            dispatch: :collect,
            user:,
            runtime_state:,
          )
        result = instantiate(node_type_class, trigger_node).trigger(ctx)
        result[:manual_trigger_function]&.call if result.is_a?(Hash)
        commit_runtime_state!(published_trigger, runtime_state)
        runtime_state.collected_trigger_data.first || {}
      end

      private

      def published_triggers(trigger_type)
        Workflow::Action::FindPublishedTriggers.call(trigger_type:)
      end

      def activation_trigger_nodes(workflow_version)
        workflow_version.nodes.select { |node| activation_trigger_node?(node_type_for(node)) }
      end

      def run_trigger(
        published_trigger,
        mode:,
        activation_mode:,
        now: Time.current.utc,
        tick: false,
        dispatch: :enqueue
      )
        node_type_class = node_type_for(published_trigger.trigger_node)
        return unless activation_trigger_node?(node_type_class)

        published_trigger.workflow.with_lock do
          runtime_state = runtime_state_for(published_trigger, tick:)
          ctx =
            Executor::TriggerExecutionContext.new(
              published_trigger:,
              mode:,
              activation_mode:,
              now:,
              dispatch:,
              runtime_state:,
            )
          instantiate(node_type_class, published_trigger.trigger_node).trigger(ctx)
          commit_runtime_state!(published_trigger, runtime_state)
        end
      end

      def runtime_state_for(published_trigger, tick: false)
        workflow = published_trigger.workflow
        trigger_node = published_trigger.trigger_node
        node_name = trigger_node["name"].to_s

        Executor::TriggerExecutionContext::RuntimeState.new(
          trigger_state: workflow.node_trigger_state(published_trigger.trigger_node_id).deep_dup,
          static_data_global: workflow.global_static_data.deep_dup,
          static_data_node: workflow.node_static_data(node_name).deep_dup,
          tick:,
        )
      end

      def commit_runtime_state!(published_trigger, runtime_state)
        workflow = published_trigger.workflow
        node_name = published_trigger.trigger_node["name"].to_s

        # trigger_state holds engine bookkeeping (dedup, last_triggered_at).
        # static_data holds user-facing runtime state; we merge the trigger's
        # flat `node:<name>` slot back without disturbing other nodes' entries.
        # We skip writing the slot if it would be empty AND the slot didn't
        # already exist, to avoid creating noise entries for triggers that
        # never touched static data (e.g. activation-time runs).
        workflow.transaction do
          workflow.update_node_trigger_state!(
            published_trigger.trigger_node_id,
            runtime_state.trigger_state,
          )

          current_node_data = workflow.node_static_data_entries
          merged_node = current_node_data.dup
          if runtime_state.static_data_node.any? || current_node_data.key?(node_name)
            merged_node[node_name] = runtime_state.static_data_node
          end
          workflow.commit_static_data!(global: runtime_state.static_data_global, node: merged_node)
        end
      end

      def node_type_for(node)
        Registry.find_node_type(node["type"], version: node["typeVersion"])
      end

      def activation_trigger_node?(node_type_class)
        node_type_class&.capability_enabled?(:activation_trigger)
      end

      def instantiate(node_type_class, node)
        node_type_class.new(
          parameters: node["parameters"],
          credentials: node["credentials"],
          webhook_id: node["webhookId"],
        )
      end

      def scheduled_minute(time)
        time.utc.change(sec: 0, usec: 0)
      end
    end
  end
end
