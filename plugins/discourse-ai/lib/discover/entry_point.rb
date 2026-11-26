# frozen_string_literal: true

module DiscourseAi
  module Discover
    class EntryPoint
      def inject_into(plugin)
        in_discover_agent_groups = ->(user) do
          user.in_any_groups?(
            AiAgent.find_by_id_from_cache(SiteSetting.ai_discover_agent)&.allowed_group_ids.to_a,
          )
        end

        plugin.add_to_serializer(
          :current_user,
          :can_use_ai_discover_agent,
          include_condition: -> do
            SiteSetting.ai_discover_enabled && scope.authenticated? &&
              SiteSetting.ai_discover_agent.present?
          end,
        ) { in_discover_agent_groups.call(scope.user) }

        plugin.add_to_serializer(
          :current_user,
          :can_use_ask_ai,
          include_condition: -> { scope.authenticated? },
        ) { DiscourseAi::Discoveries.eligible_for_user?(scope.user) }

        plugin.add_to_serializer(
          :user,
          :can_use_ai_discover_agent,
          include_condition: -> do
            SiteSetting.ai_discover_enabled && SiteSetting.ai_discover_agent.present? &&
              include_can_edit? && can_edit
          end,
        ) { in_discover_agent_groups.call(object) }

        plugin.add_to_serializer(
          :user,
          :can_use_ask_ai,
          include_condition: -> { include_can_edit? && can_edit },
        ) { DiscourseAi::Discoveries.eligible_for_user?(object) }

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
