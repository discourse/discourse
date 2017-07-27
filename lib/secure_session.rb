# session that is not stored in cookie, expires after 1.hour unconditionally
class SecureSession
  def initialize(prefix)
    @prefix = prefix
  end

  def [](key)
    $redis.get("#{@prefix}#{key}")
  end

  def []=(key, val)
    if val == nil
      $redis.del("#{@prefix}#{key}")
    else
      $redis.setex("#{@prefix}#{key}", 1.hour, val.to_s)
    end
  end
end
