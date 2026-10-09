# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module PostDestroyed
      class V1 < NodeType
        include PostLifecycle

        description(
          name: "trigger:post_destroyed",
          version: "1.0",
          defaults: {
            icon: "trash-can",
            color: "deep-orange",
          },
          group: "discourse_triggers",
          event: :post_destroyed,
          i18n_scope: PostLifecycle::I18N_SCOPE,
          output_contracts: PostLifecycle::OUTPUT_CONTRACTS,
          properties: PostLifecycle::PROPERTIES,
        )
      end
    end
  end
end
