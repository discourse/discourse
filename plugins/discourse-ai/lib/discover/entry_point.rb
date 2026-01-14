# frozen_string_literal: true

module DiscourseAi
  module Discover
    class EntryPoint
      def inject_into(plugin)
        plugin.add_to_serializer(
          :current_user,
          :can_use_ai_discover_persona,
          include_condition: -> do
            SiteSetting.ai_discover_enabled && scope.authenticated? &&
              SiteSetting.ai_discover_persona.present?
          end,
        ) do
          persona_allowed_groups =
            AiPersona.find_by(id: SiteSetting.ai_discover_persona)&.allowed_group_ids.to_a

          scope.user.in_any_groups?(persona_allowed_groups)
        end

        UserUpdater::OPTION_ATTR.push(:ai_search_discoveries)
        plugin.add_to_serializer(
          :user_option,
          :ai_search_discoveries,
          include_condition: -> do
            SiteSetting.ai_discover_enabled && SiteSetting.ai_discover_persona.present? &&
              scope.authenticated?
          end,
        ) { object.ai_search_discoveries }

        plugin.add_to_serializer(
          :current_user_option,
          :ai_search_discoveries,
          include_condition: -> do
            SiteSetting.ai_discover_enabled && SiteSetting.ai_discover_persona.present? &&
              scope.authenticated?
          end,
        ) { object.ai_search_discoveries }
      end
    end
  end
end
