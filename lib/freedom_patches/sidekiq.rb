# frozen_string_literal: true

# TODO: Remove this when releasing Discourse 3.6
module Sidekiq
  def self.old_pool
    @old_pool ||=
      begin
        ConnectionPool.new do
          Redis::Namespace.new(
            Discourse::SIDEKIQ_NAMESPACE,
            redis:
              Sidekiq::RedisClientAdapter.new(Discourse.sidekiq_redis_config(old: true)).new_client,
          )
        end
      end
  end
end
