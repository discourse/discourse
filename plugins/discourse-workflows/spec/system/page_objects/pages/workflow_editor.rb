# frozen_string_literal: true

module PageObjects
  module Pages
    class WorkflowEditor < PageObjects::Pages::Base
      def visit(workflow_id)
        page.visit("/admin/plugins/discourse-workflows/#{workflow_id}")
        self
      end

      def visit_new
        page.visit("/admin/plugins/discourse-workflows/new")
        self
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
        find(".workflows-canvas__empty-state-trigger").click
        self
      end

      def has_empty_state_add_node?
        page.has_css?(".workflows-canvas__empty-state-trigger")
      end

      def press_canvas_shortcut(key)
        find(".workflows-canvas").click
        find(".workflows-canvas").send_keys(key)
        self
      end

      def node_left(label)
        page.evaluate_script(<<~JS)
            (() => {
              const label = #{label.to_json};
              const node = [...document.querySelectorAll(".workflow-rete-node")].find(
                (element) =>
                  element.querySelector(".workflow-rete-node__label")?.textContent?.trim() === label
              );

              return node?.getBoundingClientRect().left;
            })()
          JS
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
        "action:chat_approval" => "Chat Approval",
        "core:loop_over_items" => "Loop Over Items",
      }.freeze

      def select_node_type(identifier)
        label = NODE_TYPE_LABELS.fetch(identifier, identifier)
        if page.has_css?(".workflows-node-panel", wait: 0)
          find(".workflows-node-panel__search-input").fill_in(with: label)
          find(".workflows-node-panel__item-name", text: label).click
        else
          find(".fk-d-menu__inner-content .btn", text: label).click
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
