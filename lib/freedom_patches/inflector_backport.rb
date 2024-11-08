# frozen_string_literal: true

# review per rails release, this speeds up the inflector, we are not inflecting too much at the moment, except in dev
#
# note: I am working with the rails team on including this in official rails

module ActiveSupport
  module Inflector
    LRU_CACHE_SIZE = 200
    @@lua_caches = []

    def self.clear_memoize!
      @@lua_caches.each(&:clear)
    end

    def self.memoize(*args)
      args.each do |method_name|
        cache = LruRedux::ThreadSafeCache.new(LRU_CACHE_SIZE)
        @@lua_caches << cache

        uncached = "#{method_name}_without_cache"
        alias_method uncached, method_name

        m =
          define_method(method_name) do |*arguments|
            # this avoids recursive locks
            found = true
            data = cache.fetch(arguments) { found = false }
            cache[arguments] = data = public_send(uncached, *arguments) unless found
            # so cache is never corrupted
            data.dup
          end

        # https://bugs.ruby-lang.org/issues/16897
        ruby2_keywords(m) if Module.respond_to?(:ruby2_keywords, true)
      end
    end

    memoize :pluralize,
            :singularize,
            :camelize,
            :underscore,
            :humanize,
            :titleize,
            :tableize,
            :classify,
            :foreign_key
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
            public_send(orig, *arguments)
          end
        end
      end

      clear_memoize :acronym, :plural, :singular, :irregular, :uncountable, :human, :clear
    end
  end
end
