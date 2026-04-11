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

      attr_reader :workflow, :trigger_data, :context, :node_contexts, :user
      attr_accessor :execution

      def initialize(workflow:, trigger_data:, user:, execution: nil)
        @workflow = workflow
        @trigger_data = trigger_data
        @user = user
        @execution = execution
        reset!
      end

      def reset!(resume_token: nil)
        @context = { "trigger" => trigger_data }
        @node_contexts = {}
        @context["__resume_token"] = resume_token if resume_token.present?
      end

      def restore!(context:, node_contexts:, resume_token: nil)
        @context = context.deep_stringify_keys
        @context["trigger"] ||= trigger_data
        @node_contexts = node_contexts.deep_stringify_keys
        @context["__resume_token"] = resume_token if resume_token.present?
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

      def resolver_context(extra_context = {})
        @context.merge(
          "__node_contexts" => @node_contexts,
          "__execution" => execution_variables,
          **extra_context,
        )
      end

      def node_context_for(node)
        @node_contexts[node.name] ||= {}
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
          lambda do |execution_context|
            token = execution_context.resume_token
            next if token.blank?

            signature = DiscourseWorkflows::HmacSigner.sign(token)
            "#{Discourse.base_url}/workflows/webhooks/#{token}:#{signature}"
          end,
      }.freeze

      def execution_variables
        schema_fields = ExpressionContextSchema.environment_symbols.dig("$execution", :fields) || {}
        schema_fields.each_with_object({}) do |(field_name, _), vars|
          value = EXECUTION_VALUE_SOURCES[field_name]&.call(self)
          vars[field_name] = value unless value.nil?
        end
      end
    end
  end
end
