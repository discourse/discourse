# frozen_string_literal: true

# Discourse specific cache, enforces 1 day expiry by default

# This is a bottom up implementation of ActiveSupport::Cache::Store
# this allows us to cleanly implement without using cache entries and version
# support which we do not use, in tern this makes the cache as fast as simply
# using `Discourse.redis.setex` with a more convenient API
#
# It only implements a subset of ActiveSupport::Cache::Store as we make no use
# of large parts of the interface.
#
# An additional advantage of this class is that all methods have named params
# Rails tends to use options hash for lots of stuff due to legacy reasons
# this makes it harder to reason about the API

class Cache

  # nothing is cached for longer than 1 day EVER
  # there is no reason to have data older than this clogging redis
  # it is dangerous cause if we rename keys we will be stuck with
  # pointless data
  MAX_CACHE_AGE = 1.day unless defined? MAX_CACHE_AGE

  # we don't need this feature, 1 day expiry is enough
  # it makes lookups a tad cheaper
  def self.supports_cache_versioning?
    false
  end

  def initialize(namespace: "_CACHE")
    @namespace = namespace
  end

  def redis
    Discourse.redis
  end

  def reconnect
    redis.reconnect
  end

  def keys(pattern = "*")
    redis.scan_each(match: "#{@namespace}:#{pattern}").to_a
  end

  def clear
    keys.each do |k|
      redis.del(k)
    end
  end

  def normalize_key(key)
    "#{@namespace}:#{key}"
  end

  def exist?(name)
    key = normalize_key(name)
    redis.exists(key)
  end

  # this removes a bunch of stuff we do not need like instrumentation and versioning
  def read(name)
    key = normalize_key(name)
    read_entry(key)
  end

  def write(name, value, expires_in: nil)
    write_entry(normalize_key(name), value, expires_in: nil)
  end

  def delete(name)
    redis.del(normalize_key(name))
  end

  def fetch(name, expires_in: nil, force: nil, &blk)
    if block_given?
      key = normalize_key(name)
      raw = nil

      if !force
        raw = redis.get(key)
      end

      if raw
        begin
          Marshal.load(raw)
        rescue => e
          log_first_exception(e)
        end
      else
        val = blk.call
        write_entry(key, val, expires_in: expires_in)
        val
      end
    elsif force
      raise ArgumentError, "Missing block: Calling `Cache#fetch` with `force: true` requires a block."
    else
      read(name)
    end
  end

  protected

  def log_first_exception(e)
    if !defined? @logged_a_warning
      @logged_a_warning = true
      Discourse.warn_exception(e, "Corrupt cache... skipping entry for key #{key}")
    end
  end

  def read_entry(key)
    if data = redis.get(key)
      Marshal.load(data)
    end
  rescue => e
    # corrupt cache, this can happen if Marshal version
    # changes. Log it once so we can tell it is happening.
    # should not happen under any normal circumstances, but we
    # do not want to flood logs
    log_first_exception(e)
  end

  def write_entry(key, value, expires_in: nil)
    dumped = Marshal.dump(value)
    expiry = expires_in || MAX_CACHE_AGE
    redis.setex(key, expiry, dumped)
    true
  end

end
