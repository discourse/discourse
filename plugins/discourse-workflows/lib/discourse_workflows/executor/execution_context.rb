# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class ExecutionContext
      RESERVED_KEYS = %w[
        trigger
        __resume_token
        __form_completion
        __node_contexts
        __execution
        $json
      ].freeze

      attr_reader :workflow, :trigger_data, :context, :user
      attr_accessor :execution

      def initialize(workflow:, trigger_data:, user:, execution: nil)
        @workflow = workflow
        @trigger_data = trigger_data
        @user = user
        @execution = execution
        reset!
      end

      def reset!(resume_token: SecureRandom.uuid)
        @context = { "trigger" => trigger_data }
        @node_contexts_by_id = {}
        @context["__resume_token"] = resume_token
      end

      def restore!(context:, node_contexts:, resume_token: SecureRandom.uuid)
        @context = context.deep_stringify_keys
        @context["trigger"] ||= trigger_data
        @node_contexts_by_id = normalize_node_contexts(node_contexts)
        @context["__resume_token"] = resume_token
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

      def resolver_context(extra_context = {})
        @context.merge(
          "__node_contexts" => resolver_node_contexts,
          "__execution" => execution_variables(extra_context),
          **extra_context,
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

      def form_completion
        @context["__form_completion"].presence
      end

      private

      EXECUTION_VALUE_SOURCES = {
        "id" => ->(execution_context) { execution_context.execution&.id },
        "workflow_id" => ->(execution_context) { execution_context.workflow&.id },
        "workflow_name" => ->(execution_context) { execution_context.workflow&.name },
        "resume_url" =>
          lambda do |execution_context, extra_context|
            token = execution_context.resume_token
            execution_id = execution_context.execution&.id
            next if token.blank? || execution_id.blank?

            suffix = extra_context&.dig("__webhook_suffix")
            base = "#{Discourse.base_url}/workflows/webhooks/#{execution_id}"
            base = "#{base}/#{suffix}" if suffix.present?
            "#{base}?token=#{token}"
          end,
      }.freeze

      def execution_variables(extra_context = {})
        schema_fields = ExpressionContextSchema.environment_symbols.dig("$execution", :fields) || {}
        schema_fields.each_with_object({}) do |(field_name, _), vars|
          source = EXECUTION_VALUE_SOURCES[field_name]
          next unless source
          value = source.arity > 1 ? source.call(self, extra_context) : source.call(self)
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
        node_id = workflow.find_node(node_key)&.dig("id")
        return node_id.to_s if node_id.present?

        named_node = nodes_by_name[node_key.to_s]
        return named_node["id"].to_s if named_node

        node_key.to_s
      end

      def resolver_node_contexts
        @node_contexts_by_id.each_with_object({}) do |(node_key, value), by_name|
          by_name[resolver_node_key(node_key)] = value
        end
      end

      def resolver_node_key(node_key)
        workflow.find_node(node_key)&.dig("name").presence || node_key
      end

      def node_context_key(node)
        node.id.to_s
      end

      def nodes_by_name
        @nodes_by_name ||=
          workflow
            .nodes
            .each_with_object({}) do |node, by_name|
              name = node["name"].to_s
              next if name.blank?

              by_name[name] = by_name.key?(name) ? nil : node
            end
            .compact
      end
    end
  end
end
