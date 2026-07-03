# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class ExecutionContext
      RESERVED_KEYS = %w[
        $trigger
        __resume_token
        __sandbox_elapsed_ms
        __node_contexts
        __node_runs
        __execution
        __input_item
        __input_items
        __input_sources
        __input_params
        __input_context
        __current_node_id
        __node_parameters_by_name
        __waiting_input_sources
        __pending_input_groups
        __pending_queue
        $json
        $itemIndex
      ].freeze

      attr_reader :workflow,
                  :trigger_data,
                  :context,
                  :user,
                  :workflow_name,
                  :workflow_call_caller,
                  :static_data_state
      attr_accessor :execution

      def initialize(
        workflow:,
        trigger_data:,
        user:,
        execution: nil,
        workflow_nodes: nil,
        workflow_name: nil,
        workflow_call_caller: nil
      )
        @workflow = workflow
        @workflow_nodes = workflow_nodes
        @workflow_name = workflow_name || workflow.name
        @workflow_call_caller = workflow_call_caller&.deep_stringify_keys
        @trigger_data = trigger_data
        @user = user
        @execution = execution
        @static_data_state = StaticDataState.from_workflow(workflow)
        reset!
      end

      RESUME_TOKEN_BYTES = 32

      def self.generate_resume_token
        SecureRandom.urlsafe_base64(RESUME_TOKEN_BYTES)
      end

      def reset!(resume_token: self.class.generate_resume_token)
        @context = { "$trigger" => trigger_data }
        @node_contexts_by_id = {}
        @context["__resume_token"] = resume_token
      end

      def restore!(context:, node_contexts:, resume_token: self.class.generate_resume_token)
        @context = context.deep_stringify_keys
        @context["$trigger"] ||= trigger_data
        @node_contexts_by_id = normalize_node_contexts(node_contexts)
        @context["__resume_token"] = resume_token
      end

      def use_workflow_nodes(workflow_nodes, workflow_name: nil)
        @workflow_nodes = workflow_nodes
        @workflow_name = workflow_name if workflow_name.present?
        @nodes_by_id = nil
        @nodes_by_name = nil
      end

      def store_context(key, value)
        if RESERVED_KEYS.include?(key)
          Rails.logger.warn(
            "discourse-workflows: node name '#{key}' collides with reserved context key " \
              "in workflow #{workflow.id}, context may be corrupted",
          )
        end

        @context[key] = value
      end

      def store_node_output(node, value)
        return if node.name.blank?

        store_context(node.name, value)
      end

      def store_node_run(node, inputs:, outputs:, input_sources: [])
        return if node.name.blank?

        @context["__node_runs"] ||= {}
        @context["__node_runs"][node.name] ||= []
        @context["__node_runs"][node.name] << {
          "inputs" => inputs,
          "outputs" => outputs,
          "input_sources" => input_sources,
        }
      end

      def store_waiting_input_sources(input_sources)
        @context["__waiting_input_sources"] = input_sources
      end

      def consume_waiting_input_sources
        @context.delete("__waiting_input_sources") || []
      end

      def store_pending_input_groups(inputs:, sources:, target_ids:)
        payload =
          target_ids.each_with_object({}) do |target_id, result|
            target_inputs = inputs[target_id] || {}
            next if target_inputs.blank?

            result[target_id.to_s] = {
              "inputs" => indexed_payload(target_inputs, "items"),
              "sources" => indexed_payload(sources[target_id] || {}, "source"),
            }
          end

        if payload.present?
          @context["__pending_input_groups"] = payload
        else
          @context.delete("__pending_input_groups")
        end
      end

      def consume_pending_input_groups
        @context.delete("__pending_input_groups") || {}
      end

      def store_pending_queue(entries)
        payload =
          entries.map do |node, inputs, sources|
            {
              "node_id" => node.id.to_s,
              "inputs" => indexed_payload(inputs, "items"),
              "sources" => indexed_payload(sources || {}, "source"),
            }
          end

        if payload.present?
          @context["__pending_queue"] = payload
        else
          @context.delete("__pending_queue")
        end
      end

      def consume_pending_queue
        @context.delete("__pending_queue") || []
      end

      def resolver_context(extra_context = {})
        @context.merge(
          **extra_context,
          "__node_contexts" => resolver_node_contexts,
          "__execution" => execution_variables(extra_context),
        )
      end

      def node_context_for(node)
        @node_contexts_by_id[node_context_key(node)] ||= {}
      end

      def node_contexts
        @node_contexts_by_id.deep_stringify_keys
      end

      def resume_token
        @context["__resume_token"]
      end

      private

      EXECUTION_VALUE_SOURCES = {
        "id" => ->(execution_context, _extra_context) { execution_context.execution&.id },
        "workflow_id" => ->(execution_context, _extra_context) { execution_context.workflow&.id },
        "workflow_name" => ->(execution_context, _extra_context) do
          execution_context.workflow_name
        end,
        "called_by" => ->(execution_context, _extra_context) do
          execution_context.workflow_call_caller
        end,
        "resume_url" =>
          lambda do |execution_context, extra_context|
            token = execution_context.resume_token
            execution_id = execution_context.execution&.id
            return if token.blank? || execution_id.blank?

            suffix = extra_context&.dig("__webhook_suffix")
            DiscourseWorkflows::WaitingExecution.webhook_url(
              execution_id: execution_id,
              resume_token: token,
              suffix: suffix,
            )
          end,
        "resumeFormUrl" =>
          lambda do |execution_context, _extra_context|
            token = execution_context.resume_token
            execution_id = execution_context.execution&.id
            return if token.blank? || execution_id.blank?

            DiscourseWorkflows::WaitingExecution.form_waiting_url_for(
              execution_id: execution_id,
              resume_token: token,
              absolute: true,
            )
          end,
      }.freeze

      def execution_variables(extra_context = {})
        schema_fields = ExpressionContextSchema.environment_symbols.dig("$execution", :fields) || {}
        schema_fields.each_with_object({}) do |(field_name, _), vars|
          source = EXECUTION_VALUE_SOURCES[field_name]
          next unless source
          value = source.call(self, extra_context)
          vars[field_name] = value unless value.nil?
        end
      end

      def normalize_node_contexts(node_contexts)
        node_contexts
          .deep_stringify_keys
          .each_with_object({}) do |(node_key, value), normalized|
            normalized[normalize_node_context_key(node_key)] = value
          end
      end

      def normalize_node_context_key(node_key)
        node_id = node_key.to_s
        return node_id if nodes_by_id.key?(node_id)

        named_node = nodes_by_name[node_id]
        return named_node["id"].to_s if named_node

        node_id
      end

      def resolver_node_contexts
        @node_contexts_by_id.each_with_object({}) do |(node_key, value), by_name|
          by_name[resolver_node_key(node_key)] = value
        end
      end

      def resolver_node_key(node_key)
        nodes_by_id[node_key.to_s]&.dig("name").presence || node_key
      end

      def node_context_key(node)
        node.id.to_s
      end

      def nodes_by_name
        @nodes_by_name ||=
          graph_nodes
            .each_with_object({}) do |node, by_name|
              name = node["name"].to_s
              next if name.blank?

              by_name[name] = by_name.key?(name) ? nil : node
            end
            .compact
      end

      def nodes_by_id
        @nodes_by_id ||= graph_nodes.index_by { |node| node["id"].to_s }
      end

      def graph_nodes
        @workflow_nodes || workflow.nodes
      end

      def indexed_payload(indexed_values, value_key)
        indexed_values.map { |index, value| { "index" => index.to_i, value_key => value } }
      end
    end
  end
end
