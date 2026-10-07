# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module UserCreated
      class V1 < NodeType
        description(
          name: "trigger:user_created",
          version: "1.0",
          defaults: {
            icon: "user-plus",
            color: "teal",
          },
          group: "discourse_triggers",
          event: :user_created,
          output_contracts: [{ schema: Schema::USER_EVENT_SCHEMA }],
          capabilities: {
            provides_current_user: true,
          },
        )

        def initialize(user, *)
          super(parameters: {})
          @user = user
        end

        def valid?
          @user.present? && @user.human?
        end

        def user_id
          @user.id
        end

        def output
          {
            user:
              serialize_user(@user).merge(
                staged: @user.staged?,
                created_at: @user.created_at&.iso8601,
              ),
          }
        end
      end
    end
  end
end
