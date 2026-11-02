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

        deprecated(
          superseded_by: "2.0",
          changes: {
            "user" => "actor",
          },
          notice_key: "discourse_workflows.node_deprecated.user_is_post_author",
          description_key: "discourse_workflows.node_descriptions.trigger:post_destroyed_v1",
        )
      end
    end
  end
end
