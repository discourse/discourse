# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Group
      class V1 < NodeType
        OPERATIONS = %w[add remove get].freeze

        def self.identifier
          "action:group"
        end

        def self.icon
          "user-plus"
        end

        def self.color
          "indigo"
        end

        def self.group
          "discourse_actions"
        end

        def self.property_schema
          {
            operation: {
              type: :options,
              required: true,
              options: OPERATIONS,
              default: "add",
              ui: {
                expression: true,
              },
            },
            username: {
              type: :string,
              required: true,
              visible_if: {
                operation: %w[add remove],
              },
              ui: {
                control: :user,
              },
            },
            group_id: {
              type: :integer,
              required: true,
              options_source: "groups",
              ui: {
                control: :combo_box,
              },
              control_options: {
                value_property: "id",
                name_property: "name",
                filterable: true,
                none: "discourse_workflows.group.group_id_placeholder",
              },
            },
          }
        end

        def self.load_options(source_key)
          case source_key
          when "groups"
            ::Group
              .where(automatic: false)
              .order(:name)
              .pluck(:id, :name)
              .map { |id, name| { id:, name: } }
          end
        end

        def self.output_schema
          {
            group: Schemas::Group.fields,
            user: {
              type: :object,
              fields: Schemas::User.fields,
              visible_if: {
                operation: %w[add remove],
              },
            },
          }
        end

        def execute(exec_ctx)
          items =
            exec_ctx.input_items.map do |item|
              config = exec_ctx.get_parameters(item)
              result = process(exec_ctx, config)
              wrap(result)
            end
          [items]
        end

        private

        def process(exec_ctx, config)
          group = ::Group.find(config["group_id"])
          exec_ctx.guardian.ensure_can_see_group!(group)
          group_data = Schemas::Group.resolve(group)

          return { group: group_data } if config["operation"] == "get"

          exec_ctx.guardian.ensure_can_edit_group!(group)

          user = exec_ctx.find_user(username: config["username"])

          logger = GroupActionLogger.new(exec_ctx.run_as_user, group)

          case config["operation"]
          when "remove"
            group.remove(user)
            logger.log_remove_user_from_group(user)
          else
            group.add(user)
            logger.log_add_user_to_group(user)
          end

          { group: group_data, user: Schemas::User.resolve(user) }
        end
      end
    end
  end
end
