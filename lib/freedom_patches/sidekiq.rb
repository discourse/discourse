# frozen_string_literal: true

# TODO: Remove this after the Discourse 3.5 release
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
