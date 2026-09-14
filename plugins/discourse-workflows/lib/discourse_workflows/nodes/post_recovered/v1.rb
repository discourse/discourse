# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module PostRecovered
      class V1 < NodeType
        include PostLifecycle

        description(
          name: "trigger:post_recovered",
          version: "1.0",
          defaults: {
            icon: "arrow-rotate-right",
            color: "green",
          },
          group: "discourse_triggers",
          event: :post_recovered,
          i18n_scope: PostLifecycle::I18N_SCOPE,
          output_contracts: PostLifecycle::OUTPUT_CONTRACTS,
          properties: PostLifecycle::PROPERTIES,
        )
      end
    end
  end
end
