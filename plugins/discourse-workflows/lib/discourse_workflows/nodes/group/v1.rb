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
              ui: {
                control: :combo_box,
                options_source: "groups",
                value_property: "id",
                name_property: "name",
                filterable: true,
                none: "discourse_workflows.group.group_id_placeholder",
              },
            },
          }
        end

        def self.metadata
          {
            groups:
              ::Group
                .where(automatic: false)
                .order(:name)
                .pluck(:id, :name)
                .map { |id, name| { id:, name: } },
          }
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
          run_as_user = exec_ctx.run_as_user
          items =
            exec_ctx.input_items.map do |item|
              config = exec_ctx.get_parameters(item)
              result = process(run_as_user, config)
              wrap(result)
            end
          [items]
        end

        private

        def process(run_as_user, config)
          group = ::Group.find(config["group_id"])
          Guardian.new(run_as_user).ensure_can_see_group!(group)
          group_data = Schemas::Group.resolve(group)

          return { group: group_data } if config["operation"] == "get"

          Guardian.new(run_as_user).ensure_can_edit_group!(group)

          user = User.find_by!(username: config["username"])

          logger = GroupActionLogger.new(run_as_user, group)

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
