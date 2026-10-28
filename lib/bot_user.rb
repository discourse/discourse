# frozen_string_literal: true

module BotUser
  FIRST_ID = -1200
  FLOOR_KEY = "bot_user_id_floor"
  # Keep the persisted namespace and mutex stable for existing allocation callers.
  STORE_NAMESPACE = "discourse-ai"

  def self.next_id
    DistributedMutex.synchronize("#{STORE_NAMESPACE}_#{FLOOR_KEY}") do
      id = [claimed_id, floor].compact.min - 1
      PluginStore.set(STORE_NAMESPACE, FLOOR_KEY, id)
      id
    end
  end

  def self.floor
    PluginStore.get(STORE_NAMESPACE, FLOOR_KEY)
  end

  def self.claimed_id
    [User.minimum(:id), FIRST_ID].compact.min
  end
  private_class_method :claimed_id
end
