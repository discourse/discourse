# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    # Post lifecycle triggers for moderation events, whose payload carries the user behind them as `acting_user:`.
    module PostModerationTrigger
      include PostLifecycle
      include PostLifecycle::V2

      def self.description(
        name:,
        event:,
        icon:,
        color:,
        schema: PostLifecycle::V2::OUTPUT_CONTRACTS.first[:schema]
      )
        {
          name:,
          version: "1.0",
          defaults: {
            icon:,
            color:,
          },
          group: "discourse_triggers",
          event:,
          i18n_scope: PostLifecycle::I18N_SCOPE,
          output_contracts: [{ schema: }],
          properties: PostLifecycle::PROPERTIES,
        }
      end

      # PostLifecycle's initialize would take the payload as its opts.
      def initialize(post, payload = {})
        super(post, nil, payload[:acting_user])
      end
    end
  end
end
