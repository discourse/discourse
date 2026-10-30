# frozen_string_literal: true

module DiscourseAi
  module BotUserExtensions
    # TODO: Remove after 2026-11-29 once the new allocator is deployed everywhere.
    def next_id
      # Keep reservations visible to both allocators while deployment versions overlap.
      DistributedMutex.synchronize("#{DiscourseAi::PLUGIN_NAME}_#{::BotUser::FLOOR_KEY}") do
        super.tap { |id| PluginStore.set(DiscourseAi::PLUGIN_NAME, ::BotUser::FLOOR_KEY, id) }
      end
    end

    private

    # Account references reserve IDs even while the feature is disabled.
    def claimed_id
      DB.query_single(<<~SQL, ::BotUser::FIRST_ID).first
        SELECT LEAST(
          (SELECT min(id) FROM users),
          (SELECT min(user_id) FROM ai_agents),
          (SELECT min(user_id) FROM llm_models),
          ?
        )
      SQL
    end
  end
end
