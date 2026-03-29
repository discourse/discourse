# frozen_string_literal: true

module DiscourseWorkflows
  module Actions
    module Group
      class V1 < Actions::Base
        OPERATIONS = %w[add remove].freeze

        def self.identifier
          "action:group"
        end

        def self.icon
          "user-plus"
        end

        def self.color_key
          "indigo"
        end

        def self.configuration_schema
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
          { user_id: :integer, username: :string, group_id: :integer, group_name: :string }
        end

        def execute_single(_context, item:, config:)
          user = User.find_by_username(config["username"])
          raise ActiveRecord::RecordNotFound.new("Couldn't find User") if user.nil?
          group = ::Group.find(config["group_id"])

          logger = GroupActionLogger.new(run_as_user, group)

          case config["operation"]
          when "remove"
            group.remove(user)
            logger.log_remove_user_from_group(user)
          else
            group.add(user)
            logger.log_add_user_to_group(user)
          end

          { user_id: user.id, username: user.username, group_id: group.id, group_name: group.name }
        end
      end
    end
  end
end
