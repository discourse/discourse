# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module CreateBoardColumn
        class V1 < DiscourseWorkflows::NodeType
          description(
            name: "action:create_board_column",
            version: "1.0",
            defaults: {
              icon: "boards",
              color: "light-green",
            },
            group: "discourse_actions",
            available: -> { SiteSetting.boards_enabled },
            unavailable_reason_key: "discourse_workflows.node_unavailable.requires_boards",
            capabilities: {
              run_scope: "per_item",
            },
            output_contracts: [
              { schema: Boards::Workflows::Schema::CREATE_BOARD_COLUMN_OUTPUT_SCHEMA },
            ],
            properties: {
              board_id: {
                type: :integer,
                required: true,
                type_options: {
                  load_options_method: "boards",
                },
                ui: {
                  control: :combo_box,
                },
                control_options: {
                  filterable: true,
                  value_property: :id,
                  name_property: :name,
                },
              },
              title: {
                type: :string,
                required: true,
              },
              icon: {
                type: :string,
                ui: {
                  control: :icon,
                },
              },
              color: {
                type: :string,
                ui: {
                  control: :color,
                },
              },
              tag_name: {
                type: :string,
                type_options: {
                  load_options_method: "tags",
                },
                ui: {
                  control: :combo_box,
                },
                control_options: {
                  filterable: true,
                  value_property: :name,
                  name_property: :name,
                },
              },
              default_sort: {
                type: :options,
                options: %w[priority recency],
                default: "priority",
              },
            },
          )

          def self.load_options_context(context)
            guardian = context.guardian || context.user&.guardian
            return [] unless guardian

            case context.method_name
            when "boards"
              return [] unless guardian.can_manage_boards?
              boards = Boards::Board.with_acl_permission(guardian, "manage")
              if context.filter.present?
                boards =
                  boards.where(
                    "name ILIKE ?",
                    "%#{ActiveRecord::Base.sanitize_sql_like(context.filter)}%",
                  )
              end
              boards
                .order(:name, :id)
                .select(:id, :name)
                .map { |board| { id: board.id, name: board.unicode_name } }
            when "tags"
              tags = Tag.visible(guardian)
              if context.filter.present?
                tags =
                  tags.where(
                    "name ILIKE ?",
                    "%#{ActiveRecord::Base.sanitize_sql_like(context.filter)}%",
                  )
              end
              tags.order(:name).pluck(:name).map { |name| { name: } }
            end
          end

          def execute(exec_ctx)
            guardian = (exec_ctx.user || Discourse.system_user).guardian
            items =
              exec_ctx.input_items.map.with_index do |_item, item_index|
                params =
                  %w[board_id title icon color tag_name default_sort].index_with do |name|
                    exec_ctx.get_node_parameter(name, item_index)
                  end
                %w[icon color tag_name default_sort].each do |name|
                  params[name] = params[name].presence
                end
                params["color"] = params["color"]&.delete_prefix("#")
                wrap(create_column(guardian, params))
              end
            [items]
          end

          private

          def create_column(guardian, params)
            Boards::CreateColumn.call(guardian:, params:) do
              on_success { |column:| { "column_id" => column.id, "title" => column.title } }
              on_model_not_found(:board) do
                raise_node_error!(
                  I18n.t("discourse_workflows.errors.create_board_column.board_not_found"),
                )
              end
              on_failed_policy(:can_manage) do
                raise_node_error!(
                  I18n.t("discourse_workflows.errors.create_board_column.forbidden"),
                )
              end
              on_failed_contract do |contract|
                invalid_parameters!(contract.errors.full_messages.join(", "))
              end
              on_model_not_found(:column) do |step|
                case step.exception
                when ActiveRecord::RecordInvalid
                  invalid_parameters!(step.exception.record.errors.full_messages.join(", "))
                when Discourse::InvalidParameters
                  invalid_parameters!(step.exception.message)
                else
                  raise_node_error!(I18n.t("discourse_workflows.errors.create_board_column.failed"))
                end
              end
              on_failure do
                raise_node_error!(I18n.t("discourse_workflows.errors.create_board_column.failed"))
              end
            end
          end

          def invalid_parameters!(errors)
            raise_node_error!(
              I18n.t("discourse_workflows.errors.create_board_column.invalid_params", errors:),
            )
          end
        end
      end
    end
  end
end
