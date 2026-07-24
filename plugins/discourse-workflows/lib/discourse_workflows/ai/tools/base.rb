# frozen_string_literal: true

module DiscourseWorkflows
  module Ai
    module Tools
      class Base < DiscourseAi::Agents::Tools::Tool
        def self.custom?
          true
        end

        private

        def ensure_can_manage_workflows!
          return true if context.user&.guardian&.can_manage_workflows?

          false
        end

        def not_allowed_response
          error_response(I18n.t("discourse.errors.disallowed"))
        end

        def json_safe(value)
          JSON.parse(value.to_json)
        end
      end
    end
  end
end
