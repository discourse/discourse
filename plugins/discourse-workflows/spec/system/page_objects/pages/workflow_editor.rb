# frozen_string_literal: true

module PageObjects
  module Pages
    module DiscourseWorkflows
      class WorkflowEditor < PageObjects::Pages::Base
        def visit_new
          page.visit("/admin/plugins/discourse-workflows/workflows/new")
          self
        end

        def visit(workflow_id)
          page.visit("/admin/plugins/discourse-workflows/workflows/#{workflow_id}")
          self
        end

        def close_node_configurator
          find(".workflows-configurator-modal__close").click
          self
        end

        def has_node_configurator?
          page.has_css?(".workflows-configurator-modal")
        end

        def has_no_node_configurator?
          page.has_no_css?(".workflows-configurator-modal")
        end

        def edit_name(name)
          find(".workflows-editable-title__text").click
          find(".workflows-editable-title__input").fill_in(with: name)
          find(".workflows-editable-title__input").send_keys(:return)
          self
        end

        def has_node_count?(count)
          page.has_css?(".workflow-rete-node", count: count)
        end

        def has_no_node_count?(count)
          page.has_no_css?(".workflow-rete-node", count: count)
        end

        def has_node?(label)
          page.has_css?(".workflow-rete-node__label", text: label)
        end

        def click_add_node
          find(".workflows-canvas__add-node-btn").click
          self
        end

        def click_empty_state_add_node
          first(".workflows-canvas__empty-state-trigger").click
          self
        end

        def has_empty_state_add_node?
          page.has_css?(".workflows-canvas__empty-state-trigger")
        end

        NODE_TYPE_LABELS = {
          "trigger:topic_closed" => "Topic closed",
          "trigger:post_created" => "Post created",
          "trigger:topic_created" => "Topic created",
          "trigger:webhook" => "Webhook",
          "trigger:manual" => "Manual trigger",
          "trigger:stale_topic" => "Stale topic",
          "trigger:schedule" => "Schedule",
          "condition:if" => "If",
          "condition:filter" => "Filter",
          "action:topic_tags" => "Topic tags",
          "action:code" => "Code",
          "action:topic" => "Topic",
          "action:post" => "Post",
          "action:set_fields" => "Set fields",
          "action:split_out" => "Split Out",
          "action:http_request" => "HTTP Request",
          "action:data_table" => "Data Table",
          "flow:loop_over_items" => "Loop Over Items",
        }.freeze

        NODE_TYPE_OPERATION_LABELS = {
          "action:badge" => {
            "grant" => "Grant badge",
            "revoke" => "Revoke badge",
          },
          "action:topic_tags" => {
            "add" => "Add",
            "remove" => "Remove",
          },
          "action:group" => {
            "add" => "Add to group",
            "remove" => "Remove from group",
            "get" => "Get group",
            "check_membership" => "Check membership",
          },
          "action:data_table" => {
            "insert" => "Insert",
            "get" => "Get",
            "update" => "Update",
            "delete" => "Delete",
            "upsert" => "Upsert",
          },
          "action:topic" => {
            "create" => "Create topic",
            "get" => "Get topic",
            "list" => "List topics",
          },
          "action:post" => {
            "create" => "Create post",
            "edit" => "Edit post",
            "get" => "Get post",
            "list" => "List posts",
          },
        }.freeze

        def select_node_type(identifier, operation: nil)
          label = NODE_TYPE_LABELS.fetch(identifier, identifier)
          find(".workflows-node-panel__search-input").fill_in(with: label)
          find(".workflows-node-panel__item-name", exact_text: label).click
          if operation
            operation_label = NODE_TYPE_OPERATION_LABELS.dig(identifier, operation) || operation
            find(".workflows-node-panel__item-name", text: operation_label).click
          end
          self
        end

        def double_click_node(index)
          all(".workflow-rete-node")[index].double_click
          self
        end

        def has_connection_count?(count)
          page.has_css?(".workflow-connection", count: count)
        end

        def has_condition_port_labels?
          page.has_css?(".workflow-rete-node__port-pill", text: "true", wait: 10) &&
            page.has_css?(".workflow-rete-node__port-pill", text: "false", wait: 10)
        end
      end
    end
  end
end
