# frozen_string_literal: true

require "liquid"

module DiscourseWorkflows
  module Nodes
    module Template
      class V1 < NodeType
        DEFAULT_TEMPLATE = <<~LIQUID
          Items:
          {% for item in items -%}
          - {{ item.item_index }}: {{ item.name }}
          {% endfor -%}
        LIQUID

        RUN_ONCE_FOR_ALL_ITEMS = "runOnceForAllItems"
        RUN_ONCE_FOR_EACH_ITEM = "runOnceForEachItem"
        OUTPUT_SCHEMA = {
          "$schema" => Schema::DRAFT_URI,
          "type" => "object",
          "properties" => {
            "template" => {
              "type" => "string",
            },
          },
        }.freeze

        description(
          name: "action:template",
          version: "1.0",
          defaults: {
            icon: "code",
            color: "green",
          },
          group: "data",
          capabilities: {
            run_scope: {
              parameter: "mode",
              values: {
                RUN_ONCE_FOR_EACH_ITEM => "per_item",
                RUN_ONCE_FOR_ALL_ITEMS => "all_items",
              },
            },
          },
          output_contracts: [{ schema: OUTPUT_SCHEMA }],
          properties: {
            mode: {
              type: :options,
              default: RUN_ONCE_FOR_ALL_ITEMS,
              options: [RUN_ONCE_FOR_EACH_ITEM, RUN_ONCE_FOR_ALL_ITEMS],
              no_data_expression: true,
            },
            template: {
              type: :string,
              required: true,
              default: DEFAULT_TEMPLATE,
              no_data_expression: true,
              ui: {
                control: :code,
              },
              control_options: {
                height: 240,
                lang: :text,
              },
            },
          },
        )

        def execute(exec_ctx)
          template =
            exec_ctx.get_node_parameter(
              "template",
              0,
              default: DEFAULT_TEMPLATE,
              options: {
                raw_expressions: true,
              },
            ).to_s
          mode = exec_ctx.get_node_parameter("mode", 0, default: RUN_ONCE_FOR_ALL_ITEMS)
          validate_mode!(mode)

          [
            (
              if mode == RUN_ONCE_FOR_ALL_ITEMS
                render_all_items(template, exec_ctx)
              else
                render_each_item(template, exec_ctx)
              end
            ),
          ]
        end

        private

        def validate_mode!(mode)
          return if [RUN_ONCE_FOR_ALL_ITEMS, RUN_ONCE_FOR_EACH_ITEM].include?(mode)

          raise_node_error!(
            "Invalid Template mode",
            description: "#{mode.inspect} is not a supported Template execution mode.",
          )
        end

        def render_all_items(template, exec_ctx)
          context = base_template_context(exec_ctx)

          [
            wrap(
              { "template" => render_template(template, context) },
              paired_item: paired_items(exec_ctx),
            ),
          ]
        end

        def render_each_item(template, exec_ctx)
          base_context = base_template_context(exec_ctx)

          exec_ctx.input_items.map.with_index do |input_item, item_index|
            wrap(
              {
                "template" =>
                  render_template(
                    template,
                    item_template_context(base_context, input_item, item_index),
                  ),
              },
              paired_item: exec_ctx.paired_item_for(input_item),
            )
          end
        end

        def render_template(template, context)
          Liquid::Template.parse(template).render!(context)
        rescue Liquid::Error => e
          raise_node_error!(
            I18n.t("discourse_workflows.errors.template.invalid_template"),
            description: e.message,
          )
        end

        def base_template_context(exec_ctx)
          {
            "items" => input_items(exec_ctx),
            "items_count" => exec_ctx.input_items.length,
            "vars" => (exec_ctx.vars || {}).deep_stringify_keys,
            "workflow" => workflow_context(exec_ctx),
            "execution" => execution_context(exec_ctx),
            "site_settings" => site_settings_context,
          }
        end

        def item_template_context(base_context, input_item, item_index)
          item = template_item(input_item, item_index)

          item.merge(base_context).merge("item" => item, "item_index" => item_index + 1)
        end

        def site_settings_context
          settings =
            SiteSetting
              .all_settings
              .each_with_object({}) do |setting, result|
                name = setting[:setting].to_s
                result[name] = setting[:secret] ? "[FILTERED]" : setting[:value]
              end

          SiteSetting.hidden_settings.each { |name| settings[name.to_s] ||= "[FILTERED]" }
          SiteSetting.secret_settings.each { |name| settings[name.to_s] = "[FILTERED]" }

          settings
        end

        def input_items(exec_ctx)
          exec_ctx.input_items.map.with_index do |input_item, item_index|
            template_item(input_item, item_index)
          end
        end

        def template_item(input_item, item_index)
          input_item
            .fetch("json") { {} }
            .deep_stringify_keys
            .merge("item" => input_item.deep_stringify_keys, "item_index" => item_index + 1)
        end

        def paired_items(exec_ctx)
          exec_ctx.input_items.map { |item| exec_ctx.paired_item_for(item) }
        end

        def workflow_context(exec_ctx)
          exec_ctx.get_workflow.to_h
        end

        def execution_context(exec_ctx)
          workflow = workflow_context(exec_ctx)
          {
            "id" => exec_ctx.execution_id,
            "workflow_id" => workflow["id"],
            "workflow_name" => workflow["name"],
          }.compact
        end
      end
    end
  end
end
