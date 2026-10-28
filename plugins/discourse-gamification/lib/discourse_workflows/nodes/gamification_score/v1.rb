# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module GamificationScore
        class V1 < DiscourseWorkflows::NodeType
          OUTPUT_SCHEMA = {
            "$schema" => Schema::DRAFT_URI,
            "type" => "object",
            "properties" => {
              "score_event_id" => {
                "type" => "integer",
              },
              "user_id" => {
                "type" => "integer",
              },
              "username" => {
                "type" => "string",
              },
              "points" => {
                "type" => "integer",
              },
              "date" => {
                "type" => "string",
              },
              "description" => {
                "type" => %w[string null],
              },
              "category_id" => {
                "type" => %w[integer null],
              },
            },
          }.freeze

          description(
            name: "action:gamification_score",
            version: "1.0",
            defaults: {
              icon: "trophy",
              color: "yellow",
            },
            group: "discourse_actions",
            available: -> { SiteSetting.discourse_gamification_enabled },
            unavailable_reason_key: "discourse_workflows.node_unavailable.requires_gamification",
            capabilities: {
              run_scope: "per_item",
            },
            output_contracts: [{ schema: OUTPUT_SCHEMA }],
            properties: {
              username: {
                type: :string,
                required: true,
                ui: {
                  control: :user,
                },
              },
              points: {
                type: :integer,
                required: true,
                ui: {
                  expression: true,
                },
              },
              date: {
                type: :string,
                required: false,
                ui: {
                  expression: true,
                },
              },
              description: {
                type: :string,
                required: false,
                ui: {
                  expression: true,
                },
              },
              category_id: {
                type: :integer,
                required: false,
                ui: {
                  control: :category,
                },
              },
            },
          )

          def execute(exec_ctx)
            items =
              exec_ctx.input_items.map.with_index do |_item, item_index|
                config = {
                  "username" => exec_ctx.get_node_parameter("username", item_index),
                  "points" => exec_ctx.get_node_parameter("points", item_index),
                  "date" => exec_ctx.get_node_parameter("date", item_index),
                  "description" => exec_ctx.get_node_parameter("description", item_index),
                  "category_id" => exec_ctx.get_node_parameter("category_id", item_index),
                }

                wrap(process(exec_ctx, config, item_index))
              end

            [items]
          end

          private

          def process(exec_ctx, config, item_index)
            user = exec_ctx.find_user(username: config["username"])
            points = parse_points(config["points"], item_index)
            date = parse_date(config["date"], item_index)
            category_id = parse_category_id(config["category_id"], item_index)

            event =
              ::DiscourseGamification::GamificationScoreEvent.create!(
                user_id: user.id,
                date:,
                points:,
                description: config["description"].presence,
                category_id:,
              )

            {
              score_event_id: event.id,
              user_id: user.id,
              username: user.username,
              points: event.points,
              date: event.date.to_s,
              description: event.description,
              category_id: event.category_id,
            }
          end

          def parse_points(value, item_index)
            points = Integer(value.to_s, exception: false)
            if points.nil? || points.zero?
              raise_node_error!(
                I18n.t(
                  "discourse_gamification.discourse_workflows.gamification_score.invalid_points",
                  points: value,
                ),
                item_index:,
              )
            end
            points
          end

          def parse_category_id(value, item_index)
            return if value.blank?

            category_id = Integer(value.to_s, exception: false)
            return category_id if category_id && ::Category.exists?(id: category_id)

            raise_node_error!(
              I18n.t(
                "discourse_gamification.discourse_workflows.gamification_score.invalid_category",
                category_id: value,
              ),
              item_index:,
            )
          end

          def parse_date(value, item_index)
            return Time.zone.today if value.blank?

            Date.parse(value.to_s)
          rescue Date::Error
            raise_node_error!(
              I18n.t(
                "discourse_gamification.discourse_workflows.gamification_score.invalid_date",
                date: value,
              ),
              item_index:,
            )
          end
        end
      end
    end
  end
end
