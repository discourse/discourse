# frozen_string_literal: true

require "distributed_cache"

class ApplicationSerializer < ActiveModel::Serializer
  embed :ids, include: true

  class CachedFragment
    def initialize(json)
      @json = json
    end
    def as_json(*_args)
      @json
    end
  end

  def self.expire_cache_fragment!(name_or_regexp)
    case name_or_regexp
    when String
      fragment_cache.delete(name_or_regexp)
    when Regexp
      fragment_cache
        .hash
        .keys
        .select { |k| k =~ name_or_regexp }
        .each { |k| fragment_cache.delete(k) }
    end
  end

  def self.fragment_cache
    @cache ||= DistributedCache.new("am_serializer_fragment_cache")
  end

  protected

  def cache_fragment(name, &block)
    ApplicationSerializer.fragment_cache.defer_get_set(name, &block)
  end

  def cache_anon_fragment(name, &blk)
    if scope.anonymous?
      cache_fragment(name, &blk)
    else
      blk.call
    end
  end
end
