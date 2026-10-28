# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module BadgeRevoked
      class V1 < NodeType
        include BadgeTrigger

        description(
          BadgeTrigger.description(
            name: "trigger:badge_revoked",
            event: :user_badge_revoked,
            icon: "certificate",
            color: "grey",
            output_schema:
              Schema.merge(Schema::USER_SCHEMA, Schema::BADGE_ENTITY_SCHEMA, Schema::ACTOR_SCHEMA),
          ),
        )

        def self.load_options_context(context)
          load_badge_options(context)
        end

        # Loaded again rather than read from the destroyed grant, whose associations may be cached from
        # before the badge's grant count went down.
        def initialize(payload = {})
          super(parameters: {})
          user_badge = payload[:user_badge]
          @deleted_with_owner = user_badge&.destroyed_by_association.present?
          @badge = ::Badge.find_by(id: user_badge&.badge_id)
          @user = ::User.find_by(id: user_badge&.user_id)
          @actor = payload[:acting_user]
        end

        # Deleting a user or a badge destroys its grants, but nothing was revoked.
        def valid?
          super && !@deleted_with_owner
        end
      end
    end
  end
end
