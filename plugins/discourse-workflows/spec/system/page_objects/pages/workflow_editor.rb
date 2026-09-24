# frozen_string_literal: true

module PageObjects
  module Pages
    module DiscourseWorkflows
      class WorkflowEditor < PageObjects::Pages::Base
        WORKFLOWS_PATH = "/admin/plugins/discourse-workflows/workflows"

        def visit_new
          page.visit("#{WORKFLOWS_PATH}/new")
          self
        end

        def visit(workflow_id)
          page.visit("#{WORKFLOWS_PATH}/#{workflow_id}")
          self
        end

        def visit_node(workflow, node_id)
          page.visit(node_path(workflow, node_id))
          self
        end

        def close_node_configurator
          find(".workflows-configurator-modal__close").click
          self
        end

        def add_tag(tag)
          find(".workflows-tags-editor__manage").click
          tag_selector =
            PageObjects::Components::SelectKit.new(".workflows-tags-editor .list-setting")
          tag_selector.expand
          tag_selector.search(tag)
          tag_selector.select_row_by_value(tag)
          find(".workflows-tags-editor__done").click
          self
        end

        def has_header_tag?(tag)
          page.has_css?(".workflows-tags-editor .d-table-badge", text: tag)
        end

        def rename_configured_node(name)
          find(".workflows-configurator-modal__name").click
          find(".workflows-configurator-modal__name-input").fill_in(with: name)
          find(".workflows-configurator-modal__save-name").click
          self
        end

        def has_node_configurator?(name: nil)
          if name
            page.has_css?(
              ".workflows-configurator-modal .workflows-configurator-modal__name",
              exact_text: name,
            )
          else
            page.has_css?(".workflows-configurator-modal")
          end
        end

        def has_no_node_configurator?
          page.has_no_css?(".workflows-configurator-modal")
        end

        def has_combined_topic_tag_fields?
          page.has_css?("[data-name='add_tag_names'] .mini-tag-chooser") &&
            page.has_css?("[data-name='remove_tag_names'] .mini-tag-chooser") &&
            page.has_no_css?("[data-name='replace_tag_names']") &&
            page.has_no_css?("[data-name='operation']")
        end

        def select_topic_tag_mode(mode)
          find("[data-name='mode'] select").select(mode)
          self
        end

        def set_tagged_topic(topic)
          find("[data-name='topic_id'] input[type='text']").fill_in(with: topic.id)
          self
        end

        def add_replacement_tag(tag)
          selector =
            PageObjects::Components::SelectKit.new(
              "[data-name='replace_tag_names'] .mini-tag-chooser",
            )
          selector.expand
          selector.search(tag.name)
          selector.select_row_by_value(tag.id)
          self
        end

        def has_replacement_topic_tag_fields?
          page.has_css?("[data-name='mode'] option:checked", text: "Replace all", visible: :all) &&
            page.has_css?("[data-name='replace_tag_names'] .mini-tag-chooser") &&
            page.has_css?(
              "[data-name='replace_tag_names']",
              text: I18n.t("js.discourse_workflows.topic_tags.replace_tag_names_description"),
            ) && page.has_no_css?("[data-name='add_tag_names']") &&
            page.has_no_css?("[data-name='remove_tag_names']")
        end

        def has_replacement_tag?(tag)
          page.has_css?("[data-name='replace_tag_names'] .select-kit-header", text: tag.name)
        end

        def has_legacy_topic_tag_fields?
          page.has_css?(
            "[data-name='operation'] .cm-wf-reference-pill__path",
            exact_text: "operation",
          ) && page.has_css?("[data-name='tag_names'] .mini-tag-chooser") &&
            page.has_no_css?("[data-name='add_tag_names']") &&
            page.has_no_css?("[data-name='remove_tag_names']")
        end

        def has_saved_node_configuration?
          page.has_css?(".workflows-configurator-modal__save-status--saved")
        end

        def add_status_filter(status)
          selector = PageObjects::Components::SelectKit.new("[data-name='statuses'] .multi-select")
          selector.expand
          selector.select_row_by_value(status)
          self
        end

        def has_status_filter?(status)
          page.has_css?("[data-name='statuses'] .select-kit-header", text: status)
        end

        def filter_topics_by_category(category)
          selector =
            PageObjects::Components::SelectKit.new("[data-name='category_ids'] .category-selector")
          selector.expand
          selector.select_row_by_value(category.id)
          self
        end

        def has_fixed_topic_filters?(category)
          page.has_css?("[data-name='category_ids'] .select-kit-header", text: category.name) &&
            page.has_css?("[data-name='include_subcategories']") &&
            page.has_css?("[data-name='tag_names'] .mini-tag-chooser") &&
            page.has_no_css?("[data-name='statuses']")
        end

        def filter_reviewable_type(type)
          selector =
            PageObjects::Components::SelectKit.new("[data-name='reviewable_types'] .multi-select")
          selector.expand
          selector.select_row_by_value(type)
          self
        end

        def has_fixed_reviewable_filter?(type)
          page.has_css?("[data-name='reviewable_types'] .select-kit-header", text: type) &&
            page.has_no_css?("[data-name='statuses']")
        end

        def has_workflow_path?(workflow)
          page.has_current_path?(workflow_path(workflow))
        end

        def has_node_path?(workflow, node_id)
          page.has_current_path?(node_path(workflow, node_id))
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
          "trigger:topic_reopened" => "Topic reopened",
          "trigger:reviewable_rejected" => "Review item rejected",
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

        private

        def workflow_path(workflow)
          "#{WORKFLOWS_PATH}/#{workflow.id}"
        end

        def node_path(workflow, node_id)
          "#{workflow_path(workflow)}/nodes/#{ERB::Util.url_encode(node_id)}"
        end
      end
    end
  end
end
