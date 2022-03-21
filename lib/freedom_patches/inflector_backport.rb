# frozen_string_literal: true

# review per rails release, this speeds up the inflector, we are not inflecting too much at the moment, except in dev
#
# note: I am working with the rails team on including this in official rails

SanePatch.patch("activesupport", "~> 7.0.2") do
  module FreedomPatches
    module InflectorBackport
      module Inflector
        extend ActiveSupport::Concern

        class_methods do
          LRU_CACHE_SIZE = 200
          LRU_CACHES = []

          def clear_memoize!
            LRU_CACHES.each(&:clear)
          end

          def memoize(*args)
            args.each do |method_name|
              cache = LruRedux::ThreadSafeCache.new(LRU_CACHE_SIZE)
              LRU_CACHES << cache

              uncached = "#{method_name}_without_cache"
              alias_method uncached, method_name

              m = define_method(method_name) do |*arguments|
                # this avoids recursive locks
                found = true
                data = cache.fetch(arguments) { found = false }
                unless found
                  cache[arguments] = data = public_send(uncached, *arguments)
                end
                # so cache is never corrupted
                data.dup
              end

              # https://bugs.ruby-lang.org/issues/16897
              if Module.respond_to?(:ruby2_keywords, true)
                ruby2_keywords(m)
              end
            end
          end
        end

        prepended do
          memoize :pluralize, :singularize, :camelize, :underscore, :humanize,
                  :titleize, :tableize, :classify, :foreign_key
        end

        ActiveSupport::Inflector.prepend(self)
      end

      module Inflections
        extend ActiveSupport::Concern

        class_methods do
          def clear_memoize(*args)
            args.each do |method_name|
              orig = "#{method_name}_without_clear_memoize"
              alias_method orig, method_name

              define_method(method_name) do |*arguments|
                ActiveSupport::Inflector.clear_memoize!
                public_send(orig, *arguments)
              end
            end
          end
        end

        prepended do
          clear_memoize :acronym, :plural, :singular, :irregular, :uncountable, :human, :clear
        end

        ActiveSupport::Inflector::Inflections.prepend(self)
      end
    end
  end
end
