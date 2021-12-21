# frozen_string_literal: true

class RedisSnapshot
  def self.begin_faux_transaction(redis = Discourse.redis)
    @stack ||= []
    @stack.push(RedisSnapshot.load(redis))
  end

  def self.end_faux_transaction(redis = Discourse.redis)
    @stack.pop.restore(redis)
  end

  def self.load(redis = Discourse.redis)
    keys = redis.keys

    values =
      redis.pipelined do
        keys.each do |key|
          redis.dump(key)
        end
      end

    new(keys.zip(values).delete_if { |k, v| v.nil? })
  end

  def initialize(dump)
    @dump = dump
  end

  def restore(redis = Discourse.redis)
    redis.pipelined do
      redis.flushdb

      @dump.each do |key, value|
        redis.restore(key, 0, value)
      end
    end

    nil
  end
end
