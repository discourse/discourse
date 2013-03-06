# Like a hash, just does its best to stay in sync across the farm
#
# Redis backed with an allowance for a certain amount of latency


class DistributedHash

  @lock = Mutex.new

  def self.ensure_subscribed
    @lock.synchronize do
      unless @subscribed

      end
      @subscribed = true
    end
  end


  def initialize(key, options={})
    @key = key
  end

  def []=(k,v)
  end

  def [](k)
  end

  def delete(k)
  end

  def clear
  end

end
