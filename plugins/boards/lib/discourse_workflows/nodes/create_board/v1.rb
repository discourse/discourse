# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module CreateBoard
        class V1 < DiscourseWorkflows::NodeType
          description(
            name: "action:create_board",
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
            output_contracts: [{ schema: Boards::Workflows::Schema::CREATE_BOARD_OUTPUT_SCHEMA }],
            properties: {
              name: {
                type: :string,
                required: true,
              },
              slug: {
                type: :string,
              },
              tag_names: {
                type: :array,
                ui: {
                  control: :tags,
                },
              },
              category_ids: {
                type: :array,
                ui: {
                  control: :category,
                  multiple: true,
                },
              },
              acl: {
                type: :object,
                required: true,
                ui: {
                  control: :access_control,
                  expression: false,
                },
                control_options: {
                  acl_target_type: "Boards::Board",
                  acl_target_key: Boards::Board.acl_target_key,
                  acl_target_name: "boards.manage.board",
                  required_permissions: ["manage"],
                  # TODO (martin) Not sure if this needs to be an option,
                  # could probably always allow groups from input.
                  groups_from_input: true,
                  permissions: %w[view edit manage],
                },
              },
            },
          )

          def execute(exec_ctx)
            actor = exec_ctx.user || Discourse.system_user
            items =
              exec_ctx.input_items.map.with_index do |_item, item_index|
                config = {
                  "name" => exec_ctx.get_node_parameter("name", item_index),
                  "slug" => exec_ctx.get_node_parameter("slug", item_index),
                  "tag_names" => exec_ctx.get_node_parameter("tag_names", item_index, default: []),
                  "category_ids" =>
                    exec_ctx.get_node_parameter("category_ids", item_index, default: []),
                  "acl" => exec_ctx.get_node_parameter("acl", item_index, default: []),
                }
                wrap(create_board(actor.guardian, config))
              end
            [items]
          end

          private

          def create_board(guardian, config)
            Boards::CreateBoard.call(guardian:, params: config, raw_board_params: config) do
              on_success { |board:| { "board_id" => board.id, "slug" => board.slug } }
              on_failed_policy(:can_manage) do
                raise_node_error!(I18n.t("discourse_workflows.errors.create_board.forbidden"))
              end
              on_failed_contract do |contract|
                invalid_parameters!(contract.errors.full_messages.join(", "))
              end
              on_model_not_found(:board) do |step|
                case step.exception
                when ActiveRecord::RecordInvalid
                  invalid_parameters!(step.exception.record.errors.full_messages.join(", "))
                when Discourse::InvalidParameters
                  invalid_parameters!(step.exception.message)
                else
                  raise_node_error!(I18n.t("discourse_workflows.errors.create_board.failed"))
                end
              end
              on_failed_step(:create_acl) do
                raise_node_error!(I18n.t("discourse_workflows.errors.create_board.acl_failed"))
              end
              on_failure do
                raise_node_error!(I18n.t("discourse_workflows.errors.create_board.failed"))
              end
            end
          end

          def invalid_parameters!(errors)
            raise_node_error!(
              I18n.t("discourse_workflows.errors.create_board.invalid_params", errors:),
            )
          end
        end
      end
    end
  end
end
