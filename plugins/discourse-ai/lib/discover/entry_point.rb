# frozen_string_literal: true

module DiscourseAi
  module Discover
    class EntryPoint
      def inject_into(plugin)
        plugin.add_to_serializer(
          :current_user,
          :can_use_ai_discover_agent,
          include_condition: -> { scope.authenticated? },
        ) { DiscourseAi::Discoveries.eligible_for_user?(scope.user) }

        UserUpdater::OPTION_ATTR.push(:ai_search_discoveries)
        plugin.add_to_serializer(
          :user_option,
          :ai_search_discoveries,
          include_condition: -> do
            scope.authenticated? && DiscourseAi::Discoveries.eligible_for_user?(scope.user)
          end,
        ) { object.ai_search_discoveries }

        plugin.add_to_serializer(
          :current_user_option,
          :ai_search_discoveries,
          include_condition: -> do
            scope.authenticated? && DiscourseAi::Discoveries.eligible_for_user?(scope.user)
          end,
        ) { object.ai_search_discoveries }
      end
    end
  end
end
