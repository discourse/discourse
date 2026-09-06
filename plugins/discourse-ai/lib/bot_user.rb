# frozen_string_literal: true

module DiscourseAi
  module BotUser
    FIRST_ID = -1200
    FLOOR_KEY = "bot_user_id_floor"

    def self.next_id
      DistributedMutex.synchronize("#{DiscourseAi::PLUGIN_NAME}_#{FLOOR_KEY}") do
        id = [claimed_id, floor].compact.min - 1
        PluginStore.set(DiscourseAi::PLUGIN_NAME, FLOOR_KEY, id)
        id
      end
    end

    def self.floor
      PluginStore.get(DiscourseAi::PLUGIN_NAME, FLOOR_KEY)
    end

    def self.claimed_id
      DB.query_single(<<~SQL, FIRST_ID).first
          SELECT LEAST(
            (SELECT min(id) FROM users),
            (SELECT min(user_id) FROM ai_agents),
            (SELECT min(user_id) FROM llm_models),
            ?
          )
        SQL
    end
    private_class_method :claimed_id
  end
end
