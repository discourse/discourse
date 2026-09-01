# frozen_string_literal: true

module DiscourseWorkflows
  class FormCompletion
    NODE_TYPE = "action:form"
    COMPLETION_PAGE_TYPE = "completion"
    DEFAULT_ON_SUBMISSION = "completion_screen"
    METADATA_KEY = "form_completion"

    class << self
      def from_execution(execution)
        execution
          .execution_data
          &.steps_array
          .to_a
          .select do |step|
            step["status"] == Executor::Step::SUCCESS && step.dig("metadata", METADATA_KEY).present?
          end
          .last
          &.dig("metadata", METADATA_KEY)
      end

      def for_node(node, resolver:)
        completion_payload(resolver.resolve_hash(parameters_for(node)))
      end

      def completion_node?(node)
        node.present? && NodeData.read(node, "type") == NODE_TYPE &&
          parameters_for(node).fetch("page_type") { "page" } == COMPLETION_PAGE_TYPE
      end

      def completion_payload(config)
        {
          "on_submission" => config.fetch("on_submission") { DEFAULT_ON_SUBMISSION },
          "completion_title" => sanitize_html(config["completion_title"]),
          "completion_message" => sanitize_html(config["completion_message"]),
          "redirect_url" => config["redirect_url"],
          "completion_text" => sanitize_html(config["completion_text"]),
        }
      end
    end
    private_class_method :completion_payload

    class << self
      def sanitize_html(value)
        return if value.nil?

        DiscourseWorkflows::Forms::Schema.sanitize_html(value)
      end
    end
    private_class_method :sanitize_html

    class << self
      def parameters_for(node)
        NodeData.parameters(node).deep_stringify_keys
      end
    end
    private_class_method :parameters_for
  end
end
