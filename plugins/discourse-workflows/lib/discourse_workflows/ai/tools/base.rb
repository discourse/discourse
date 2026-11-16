# frozen_string_literal: true

module DiscourseWorkflows
  module Ai
    module Tools
      class Base < DiscourseAi::Agents::Tools::Tool
        private

        def ensure_can_manage_workflows!
          !!context.user&.guardian&.can_manage_workflows?
        end

        def not_allowed_response
          error_response(I18n.t("invalid_access"))
        end

        def json_safe(value)
          JSON.parse(value.to_json)
        end
      end
    end
  end
end
