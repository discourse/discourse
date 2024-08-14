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
  MAX_CACHE_AGE = 1.day unless defined?(MAX_CACHE_AGE)

  attr_reader :namespace

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
    keys.each { |k| redis.del(k) }
  end

  def normalize_key(key)
    "#{@namespace}:#{key}"
  end

  def exist?(name)
    key = normalize_key(name)
    redis.exists?(key)
  end

  # this removes a bunch of stuff we do not need like instrumentation and versioning
  def read(name, hash_field: nil)
    key = normalize_key(name)
    read_entry(key, hash_field: hash_field).tap { |entry| break if entry == :__corrupt_cache__ }
  end

  def write(name, value, expires_in: nil, hash_field: nil)
    write_entry(normalize_key(name), value, expires_in: expires_in, hash_field: hash_field)
  end

  def delete(name, hash_field: nil)
    if hash_field
      redis.hdel(normalize_key(name), hash_field)
    else
      redis.del(normalize_key(name))
    end
  end

  def fetch(name, expires_in: nil, force: nil, hash_field: nil, &blk)
    if !block_given?
      if force
        raise ArgumentError,
              "Missing block: Calling `Cache#fetch` with `force: true` requires a block."
      end
      return read(name, hash_field: hash_field)
    end

    key = normalize_key(name)

    if !force
      if raw = redis_get(key, hash_field: hash_field)
        entry = decode_entry(raw, key)
        return entry if entry != :__corrupt_cache__
      end
    end

    val = blk.call
    write_entry(key, val, expires_in: expires_in, hash_field: hash_field)
    val
  end

  protected

  def redis_get(name, hash_field: nil)
    if hash_field
      redis.hget(name, hash_field)
    else
      redis.get(name)
    end
  end

  def redis_set(name, expiry, dumped, hash_field: nil)
    if hash_field
      redis.hset(name, hash_field, dumped)
      redis.expire(name, expiry)
    else
      redis.setex(name, expiry, dumped)
    end
  end

  def log_first_exception(e, key)
    return if defined?(@logged_a_warning)
    @logged_a_warning = true
    Discourse.warn_exception(e, message: "Corrupt cache... skipping entry for key #{key}")
  end

  def decode_entry(raw, key)
    Marshal.load(raw) # rubocop:disable Security/MarshalLoad
  rescue => e
    # corrupt cache, this can happen if Marshal version
    # changes. Log it once so we can tell it is happening.
    # should not happen under any normal circumstances, but we
    # do not want to flood logs
    log_first_exception(e, key)
    :__corrupt_cache__
  end

  def read_entry(key, hash_field: nil)
    if data = redis_get(key, hash_field: hash_field)
      decode_entry(data, key)
    end
  end

  def write_entry(key, value, expires_in: nil, hash_field: nil)
    dumped = Marshal.dump(value)
    expiry = expires_in || MAX_CACHE_AGE
    redis_set(key, expiry, dumped, hash_field: hash_field)
    true
  end
end
