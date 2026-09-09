# frozen_string_literal: true

module DiscourseAi
  module Discoveries
    class EntryPoint
      def inject_into(plugin)
        UserUpdater::OPTION_ATTR.push(:ai_ask_ai_default)

        %i[user_option current_user_option].each do |serializer|
          plugin.add_to_serializer(
            serializer,
            :ai_ask_ai_default,
            include_condition: -> { SiteSetting.ai_ask_ai_enabled && scope.authenticated? },
          ) { object.ai_ask_ai_default }
        end
      end
    end
  end
end
