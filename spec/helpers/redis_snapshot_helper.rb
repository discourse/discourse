# frozen_string_literal: true

module RedisSnapshotHelper
  def use_redis_snapshotting
    puts "DEPRECATION NOTICE: `use_redis_snapshotting` has been deprecated without replacement as we now flush the Redis database after each test."
  end
end
