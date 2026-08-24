# frozen_string_literal: true

module DiscourseAi
  module Discover
    class EntryPoint
      USER_OPTION_ATTRIBUTES = %i[ai_search_discoveries].freeze

      def inject_into(plugin)
        plugin.add_to_serializer(
          :current_user,
          :can_use_ai_discover_agent,
          include_condition: -> { scope.authenticated? },
        ) { DiscourseAi::Discoveries.eligible_for_user?(scope.user) }

        UserUpdater::OPTION_ATTR.concat(USER_OPTION_ATTRIBUTES).uniq!
        eligible_for_discoveries =
          lambda do
            cache_key = :@ai_search_discoveries_eligible_for_user
            if !instance_variable_defined?(cache_key)
              instance_variable_set(
                cache_key,
                scope.authenticated? && DiscourseAi::Discoveries.eligible_for_user?(scope.user),
              )
            end
            instance_variable_get(cache_key)
          end
        USER_OPTION_ATTRIBUTES.each do |attribute|
          %i[user_option current_user_option].each do |serializer|
            plugin.add_to_serializer(
              serializer,
              attribute,
              include_condition: eligible_for_discoveries,
            ) { object.public_send(attribute) }
          end
        end
      end
    end
  end
end
