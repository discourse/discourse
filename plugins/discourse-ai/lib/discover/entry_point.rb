# frozen_string_literal: true

module DiscourseAi
  module Discover
    class EntryPoint
      def inject_into(plugin)
        plugin.add_to_serializer(
          :current_user,
          :can_use_ai_discover_agent,
          include_condition: -> do
            SiteSetting.ai_discover_enabled && scope.authenticated? &&
              SiteSetting.ai_discover_agent.present?
          end,
        ) do
          agent_allowed_groups =
            AiAgent.find_by(id: SiteSetting.ai_discover_agent)&.allowed_group_ids.to_a

          scope.user.in_any_groups?(agent_allowed_groups)
        end

        plugin.add_to_serializer(
          :current_user,
          :can_use_ai_discover_agent,
          include_condition: -> do
            SiteSetting.ai_discover_enabled && scope.authenticated? &&
              SiteSetting.ai_discover_agent.present?
          end,
        ) do
          agent_allowed_groups =
            AiAgent.find_by(id: SiteSetting.ai_discover_agent)&.allowed_group_ids.to_a

          scope.user.in_any_groups?(agent_allowed_groups)
        end

        UserUpdater::OPTION_ATTR.push(:ai_search_discoveries)
        plugin.add_to_serializer(
          :user_option,
          :ai_search_discoveries,
          include_condition: -> do
            SiteSetting.ai_discover_enabled && SiteSetting.ai_discover_agent.present? &&
              scope.authenticated?
          end,
        ) { object.ai_search_discoveries }

        plugin.add_to_serializer(
          :current_user_option,
          :ai_search_discoveries,
          include_condition: -> do
            SiteSetting.ai_discover_enabled && SiteSetting.ai_discover_agent.present? &&
              scope.authenticated?
          end,
        ) { object.ai_search_discoveries }
      end
    end
  end
end
