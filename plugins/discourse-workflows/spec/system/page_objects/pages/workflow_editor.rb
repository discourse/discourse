# frozen_string_literal: true

module PageObjects
  module Pages
    class WorkflowEditor < PageObjects::Pages::Base
      def visit_new
        page.visit("/admin/plugins/discourse-workflows/new")
        self
      end

      def fill_name(name)
        find(".workflows-editor__name-input").fill_in(with: name)
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
        find(".workflows-add-node-button__trigger").click
        self
      end

      def click_empty_state_add_node
        find(".workflows-canvas__empty-state-trigger").click
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
        "action:append_tags" => "Append tags",
        "action:code" => "Code",
        "action:fetch_topic" => "Fetch topic",
        "action:create_post" => "Create post",
        "action:create_topic" => "Create topic",
        "action:set_fields" => "Set fields",
        "action:split_out" => "Split Out",
        "action:http_request" => "HTTP Request",
        "action:data_table" => "Data Table",
        "action:wait_for_approval" => "Wait For Approval",
        "core:loop_over_items" => "Loop Over Items",
      }.freeze

      def select_node_type(identifier)
        label = NODE_TYPE_LABELS.fetch(identifier, identifier)
        find(".fk-d-menu__inner-content .btn", text: label).click
        self
      end

      def double_click_node(index)
        all(".workflow-rete-node")[index].double_click
        self
      end

      def has_connection_count?(count)
        page.has_css?(".workflow-connection-svg", count: count)
      end

      def has_condition_port_labels?
        page.has_css?(".workflow-rete-node__port-pill", text: "true") &&
          page.has_css?(".workflow-rete-node__port-pill", text: "false")
      end
    end
  end
end
