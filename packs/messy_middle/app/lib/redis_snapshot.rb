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

    values = redis.pipelined { |batch| keys.each { |key| batch.dump(key) } }

    new(keys.zip(values).delete_if { |k, v| v.nil? })
  end

  def initialize(dump)
    @dump = dump
  end

  def restore(redis = Discourse.redis)
    redis.pipelined do |batch|
      batch.flushdb

      @dump.each { |key, value| batch.restore(key, 0, value) }
    end

    nil
  end
end
