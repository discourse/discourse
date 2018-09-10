# review per rails release, this speeds up the inflector, we are not inflecting too much at the moment, except in dev
#
# note: I am working with the rails team on including this in official rails

module ActiveSupport
  module Inflector

    LRU_CACHE_SIZE = 200
    LRU_CACHES = []

    def self.clear_memoize!
      LRU_CACHES.each(&:clear)
    end

    def self.memoize(*args)
      args.each do |method_name|
        cache = LruRedux::ThreadSafeCache.new(LRU_CACHE_SIZE)
        LRU_CACHES << cache

        uncached = "#{method_name}_without_cache"
        alias_method uncached, method_name

        define_method(method_name) do |*arguments|
          # this avoids recursive locks
          found = true
          data = cache.fetch(arguments) { found = false }
          unless found
            cache[arguments] = data = send(uncached, *arguments)
          end
          # so cache is never corrupted
          data.dup
        end
      end
    end

    memoize :pluralize, :singularize, :camelize, :underscore, :humanize,
            :titleize, :tableize, :classify, :foreign_key
  end
end

module ActiveSupport
  module Inflector
    class Inflections
      def self.clear_memoize(*args)
        args.each do |method_name|
          orig = "#{method_name}_without_clear_memoize"
          alias_method orig, method_name

          define_method(method_name) do |*arguments|
            ActiveSupport::Inflector.clear_memoize!
            send(orig, *arguments)
          end
        end
      end

      clear_memoize :acronym, :plural, :singular, :irregular, :uncountable, :human, :clear
    end
  end
end
