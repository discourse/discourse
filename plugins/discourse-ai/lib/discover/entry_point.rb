# frozen_string_literal: true

module DiscourseAi
  module Discover
    class EntryPoint
      USER_OPTION_ATTRIBUTES = %i[
        ai_search_discoveries
        ai_search_discoveries_mode
        ai_search_discoveries_show_summary
        ai_search_discoveries_summary_detail
        ai_search_discoveries_related_count
      ].freeze

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

        plugin.add_model_callback(UserOption, :validate) do
          if !DiscourseAi::Discoveries::SEARCH_MODES.value?(ai_search_discoveries_mode)
            errors.add(:ai_search_discoveries_mode, :inclusion)
          end
          if !DiscourseAi::Discoveries::SUMMARY_DETAILS.value?(ai_search_discoveries_summary_detail)
            errors.add(:ai_search_discoveries_summary_detail, :inclusion)
          end
          if !ai_search_discoveries_related_count.to_i.between?(
               DiscourseAi::Discoveries::MIN_RELATED_DISCUSSIONS,
               DiscourseAi::Discoveries::MAX_RELATED_DISCUSSIONS,
             )
            errors.add(:ai_search_discoveries_related_count, :inclusion)
          end
        end
      end
    end
  end
end
