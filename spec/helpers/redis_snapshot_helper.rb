# frozen_string_literal: true

module RedisSnapshotHelper
  def use_redis_snapshotting
    before(:all) do
      RedisSnapshot.begin_faux_transaction
    end

    after(:all) do
      RedisSnapshot.end_faux_transaction
    end

    before(:each) do
      RedisSnapshot.begin_faux_transaction
    end

    after(:each) do
      RedisSnapshot.end_faux_transaction
    end
  end
end
