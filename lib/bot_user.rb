# frozen_string_literal: true

class BotUser
  FIRST_ID = -1200
  FLOOR_KEY = "bot_user_id_floor"

  def initialize(namespace)
    @store = PluginStore.new(namespace.to_s)
  end

  def next_id
    DistributedMutex.synchronize(FLOOR_KEY) do
      id = [claimed_id, floor].compact.min - 1
      @store.set(FLOOR_KEY, id)
      id
    end
  end

  private

  # Include every namespace so IDs reserved before user creation cannot collide.
  def floor
    PluginStoreRow
      .where(key: FLOOR_KEY, type_name: %w[Integer Fixnum])
      .pluck(:value)
      .map(&:to_i)
      .min
  end

  def claimed_id
    [User.minimum(:id), FIRST_ID].compact.min
  end
end
