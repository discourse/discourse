# frozen_string_literal: true

module DiscourseDataExplorer
  module Adapters
    class CachedResults < JsonApiKit::Adapter
      def records_for(request, scoped_to: nil)
        resource.apply_filters(restricted_scope(scoped_to), request.filtering).cached_results(
          resource.guardian.user,
        )
      end

      def scope_for(guardian)
        return resource.scope_definition.call(guardian) if resource.scope_definition
        Selection.new(queries: [], params: {})
      end

      def record_for(id)
        cached_result_for(QueryResultCache::Key.parse(id))
      rescue QueryResultCache::Key::Invalid
        raise JsonApiKit::NotFound
      end

      def related_records(_relationship, owners:, owner_resource:)
        RelatedResults.new(resource, owners:)
      end

      private

      def cached_result_for(key)
        query = query_resource.record_for(key.query_id)
        raise JsonApiKit::NotFound unless QueryRunner.cacheable?(query) && available?(query)

        QueryResultCache.read_entry(key, resource.guardian.user) || raise(JsonApiKit::NotFound)
      end

      def restricted_scope(scoped_to)
        return scope_for(resource.guardian) unless scoped_to
        return scoped_to unless resource.scope_definition
        scoped_to.within(scope_for(resource.guardian))
      end

      def available?(query)
        !resource.scope_definition || scope_for(resource.guardian).include?(query)
      end

      def query_resource = @query_resource ||= resource.resource_for(QueryResource)
    end
  end
end
