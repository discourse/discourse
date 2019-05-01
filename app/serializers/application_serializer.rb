require 'distributed_cache'

class ApplicationSerializer < ActiveModel::Serializer
  extend DistributedCache::Mixin

  embed :ids, include: true

  class CachedFragment
    def initialize(json)
      @json = json
    end
    def as_json(*_args)
      @json
    end
  end

  def self.expire_cache_fragment!(name)
    fragment_cache.delete(name)
  end

  distributed_cache :fragment_cache, 'am_serializer_fragment_cache'

  protected

  def cache_fragment(name)
    ApplicationSerializer.fragment_cache[name] ||= yield
  end

  def cache_anon_fragment(name, &blk)
    if scope.anonymous?
      cache_fragment(name, &blk)
    else
      blk.call
    end
  end
end
