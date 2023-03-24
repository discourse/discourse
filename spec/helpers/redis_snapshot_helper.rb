# frozen_string_literal: true

module RedisSnapshotHelper
  def use_redis_snapshotting
    before(:each) { RedisSnapshot.begin_faux_transaction }

    after(:each) { RedisSnapshot.end_faux_transaction }
  end
end
