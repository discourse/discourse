# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::UpdatePinData
    include Service::Base

    UNPIN = Object.new.freeze

    params do
      attribute :workflow_id, :integer
      attribute :node_name, :string
      attribute :items, default: -> { UNPIN }

      validates :workflow_id, presence: true
      validates :node_name, presence: true

      def unpin?
        items == UNPIN
      end

      def normalized_items
        return nil if unpin?

        normalized =
          DiscourseWorkflows::Item
            .normalize_items(Array.wrap(items))
            .map { |item| item.slice("json", DiscourseWorkflows::Item::PAIRED_ITEM_KEY) }
        DiscourseWorkflows::ItemContract.validate_items!(normalized, source: "pin_data")
        normalized
      end
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :workflow
    model :node
    policy :items_are_valid
    policy :node_supports_pinning
    policy :within_size_cap

    transaction { model :workflow, :persist_pin_data }

    step :publish_pin_data_update

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    def fetch_node(workflow:, params:)
      workflow.nodes.find { |n| n["name"] == params.node_name }
    end

    def items_are_valid(params:)
      return true if params.unpin?

      params.normalized_items
      true
    rescue DiscourseWorkflows::Item::InconsistentItemFormatError,
           DiscourseWorkflows::ItemContract::Error
      false
    end

    def node_supports_pinning(node:, params:)
      return true if params.unpin?

      node_type_class = registered_node_type_for(node)
      return false if node_type_class.nil?

      Array(node_type_class.outputs).length <= 1
    end

    def within_size_cap(workflow:, params:)
      candidate = (workflow.pin_data || {}).dup
      if params.unpin?
        candidate.delete(params.node_name)
      else
        candidate[params.node_name] = params.normalized_items
      end

      candidate.to_json.bytesize <= SiteSetting.discourse_workflows_max_pin_data_bytes
    end

    def persist_pin_data(workflow:, params:)
      items = params.unpin? ? nil : params.normalized_items
      workflow.update_node_pin_data!(params.node_name, items)
      workflow
    end

    def publish_pin_data_update(workflow:, params:)
      MessageBus.publish(
        "/discourse-workflows/workflows/#{workflow.id}/pin_data",
        {
          node_name: params.node_name,
          pinned: !params.unpin?,
          pinned_node_names: workflow.pinned_node_names,
        },
        group_ids: [Group::AUTO_GROUPS[:admins]],
      )
    end

    def registered_node_type_for(node)
      DiscourseWorkflows::Registry.find_node_type(node["type"], version: node["typeVersion"])
    end
  end
end
