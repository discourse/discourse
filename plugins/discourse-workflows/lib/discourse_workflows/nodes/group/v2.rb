# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Group
      class V2 < V1
        OPERATIONS = %w[get check_membership].freeze
        DEFAULT_OPERATION = "check_membership"

        description(
          superclass.description.merge(
            version: "2.0",
            defaults: {
              icon: "users",
              color: "indigo",
            },
            output_contracts: [
              {
                variants: [
                  {
                    schema: Schema::GROUP_SCHEMA,
                    display_options: {
                      show: {
                        operation: ["get"],
                      },
                    },
                  },
                  {
                    schema: Schema::GROUP_MEMBERSHIP_SCHEMA,
                    mode: :merge,
                    display_options: {
                      show: {
                        operation: ["check_membership"],
                      },
                    },
                  },
                ],
              },
            ],
            properties: {
              **V1.properties.except(:set_primary_group),
              operation:
                V1.properties[:operation].merge(options: OPERATIONS, default: DEFAULT_OPERATION),
              username:
                V1.properties[:username].merge(
                  display_options: {
                    show: {
                      operation: ["check_membership"],
                    },
                  },
                ),
            },
          ),
        )

        private

        # An expression can still resolve to one of 1.0's membership changes, which moved to their own nodes.
        def process(exec_ctx, config, item_index)
          if config["operation"] != "get"
            raise_node_error!(
              I18n.t(
                "discourse_workflows.errors.unknown_operation",
                operation: config["operation"],
              ),
              item_index:,
            )
          end

          super
        end
      end
    end
  end
end
