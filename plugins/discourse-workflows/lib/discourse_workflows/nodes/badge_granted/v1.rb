# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module BadgeGranted
      class V1 < NodeType
        include BadgeTrigger

        description(
          BadgeTrigger.description(
            name: "trigger:badge_granted",
            event: :user_badge_granted,
            icon: "certificate",
            color: "yellow",
            output_schema: Schema.merge(Schema::BADGE_GRANTED_SCHEMA, Schema::ACTOR_SCHEMA),
          ),
        )

        def self.load_options_context(context)
          load_badge_options(context)
        end

        def initialize(badge_id, user_id, payload = {})
          super(parameters: {})
          @badge = ::Badge.find_by(id: badge_id)
          @user = ::User.find_by(id: user_id)
          @actor = payload[:acting_user]
        end
      end
    end
  end
end
