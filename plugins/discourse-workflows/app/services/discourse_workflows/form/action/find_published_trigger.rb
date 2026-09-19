# frozen_string_literal: true

module DiscourseWorkflows
  class Form::Action::FindPublishedTrigger < Service::ActionBase
    option :uuid
    option :workflow, optional: true

    def call
      Workflow::Action::FindPublishedTriggers.call(
        trigger_type: NodeDataShape::FORM_TRIGGER_TYPE,
        filter: filter_by_uuid_and_workflow,
      ).first
    end

    private

    def filter_by_uuid_and_workflow
      lambda do |published_trigger|
        node = published_trigger.trigger_node
        trigger_workflow = published_trigger.workflow
        next false if workflow && trigger_workflow.id != workflow.id

        node[WorkflowDocument.node_webhook_id_key] == uuid
      end
    end
  end
end
