# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module UserFirstLoggedIn
      class V1 < NodeType
        description(
          name: "trigger:user_first_logged_in",
          version: "1.0",
          defaults: {
            icon: "right-to-bracket",
            color: "teal",
          },
          group: "discourse_triggers",
          event: :user_first_logged_in,
          output_contracts: [{ schema: Schema::USER_SCHEMA }],
          capabilities: {
            provides_current_user: true,
          },
        )

        def initialize(user)
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
          { user: serialize_user(@user) }
        end
      end
    end
  end
end
