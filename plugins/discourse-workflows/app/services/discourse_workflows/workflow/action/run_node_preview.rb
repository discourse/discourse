# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::Action::RunNodePreview < Service::ActionBase
    MAX_ITEMS = 25

    option :workflow_snapshot, optional: true
    option :node, optional: true
    option :node_type_class
    option :preview_context
    option :parameters, optional: true
    option :user

    def call
      sandbox = DiscourseWorkflows::JsSandbox.new(preview_context, user: user)
      resolver =
        DiscourseWorkflows::ExpressionResolver.new(preview_context, sandbox: sandbox, user: user)

      success_payload(execute_node(resolver))
    rescue DiscourseWorkflows::NodeError,
           DiscourseWorkflows::JsSandbox::SandboxError,
           DiscourseWorkflows::JsSandbox::BudgetExceededError,
           DiscourseWorkflows::JsSandbox::PayloadTooLargeError,
           MiniRacer::Error => e
      error_payload(e.message)
    rescue StandardError => e
      Discourse.warn_exception(e, message: "discourse-workflows: node preview failed")
      error_payload(I18n.t("discourse_workflows.errors.node_preview_failed"))
    ensure
      resolver&.dispose
      sandbox&.dispose
    end

    private

    def items
      @items ||=
        begin
          pinned = workflow_snapshot&.pinned_items_for(node) if node
          pinned.presence || Array(preview_context["__input_items"])
        end
    end

    def node_parameters
      @node_parameters ||= (parameters || node&.parameters || {}).deep_stringify_keys
    end

    def execute_node(resolver)
      @execution_context = execution_context(resolver)
      node_type_class.new(parameters: node_parameters, credentials: {}).execute(@execution_context)
    end

    def execution_context(resolver)
      DiscourseWorkflows::Executor::NodeExecutionContext.new(
        input_items: items,
        parameters: node_parameters,
        credentials: {
        },
        property_schema: node_type_class.property_schema,
        credential_schema: node_type_class.credentials,
        node_identifier: node_type_class.identifier,
        resolver: resolver,
        resolver_context: preview_context,
        user: user,
      )
    end

    def success_payload(outputs)
      ports = Array(outputs).map { |port| Array(port) }

      {
        input_count: items.length,
        outputs: ports.map { |port| port.first(MAX_ITEMS) },
        output_counts: ports.map(&:length),
        truncated: ports.any? { |port| port.length > MAX_ITEMS },
        log: log_entries,
      }
    end

    def error_payload(message)
      { input_count: items.length, outputs: [], error: message, log: log_entries }
    end

    def log_entries
      @execution_context&.log&.as_json || []
    end
  end
end
