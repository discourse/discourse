# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module UserTrustLevelChanged
      class V1 < NodeType
        OUTPUT_SCHEMA =
          Schema.merge(
            Schema::USER_SCHEMA,
            Schema.document(
              "old_trust_level" => {
                "type" => "integer",
              },
              "new_trust_level" => {
                "type" => "integer",
              },
            ),
          ).freeze

        description(
          name: "trigger:user_trust_level_changed",
          version: "1.0",
          defaults: {
            icon: "user-shield",
            color: "teal",
          },
          group: "discourse_triggers",
          event: :user_promoted,
          output_contracts: [{ schema: OUTPUT_SCHEMA }],
          properties: {
            old_trust_levels: {
              type: :multi_options,
              default: [],
              options: trust_level_options,
            },
            new_trust_levels: {
              type: :multi_options,
              default: [],
              options: trust_level_options,
            },
          },
          capabilities: {
            provides_current_user: true,
          },
        )

        def initialize(data)
          super(parameters: {})
          @user = ::User.find_by(id: data[:user_id])
          @old_trust_level = data[:old_trust_level]
          @new_trust_level = data[:new_trust_level]
        end

        def valid?
          @user.present? && @user.human? && @old_trust_level != @new_trust_level
        end

        def user_id
          @user.id
        end

        def output
          {
            user: serialize_user(@user),
            old_trust_level: @old_trust_level,
            new_trust_level: @new_trust_level,
          }
        end

        def matches?(trigger_ctx)
          matches_level?(trigger_ctx, "old_trust_levels", @old_trust_level) &&
            matches_level?(trigger_ctx, "new_trust_levels", @new_trust_level)
        end

        private

        def matches_level?(trigger_ctx, parameter, level)
          levels =
            Array.wrap(trigger_ctx.get_node_parameter(parameter, [])).compact_blank.map(&:to_s)

          levels.empty? || levels.include?(level.to_s)
        end
      end
    end
  end
end
