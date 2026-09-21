# frozen_string_literal: true

module DiscourseWorkflows
  module NodePacks
    module Runtime
      module_function

      def version
        Discourse.redis.get(version_key).to_i
      end

      def bump!
        Discourse.redis.incr(version_key)
        clear!
      end

      def node_classes
        database = RailsMultisite::ConnectionManagement.current_db
        stamp = version
        cached = caches[database]
        return cached[:classes] if cached && cached[:stamp] == stamp

        classes =
          NodePack
            .installed
            .includes(:definitions)
            .flat_map do |pack|
              pack.definitions.map { |definition| ClassFactory.build(definition, pack) }
            end
            .freeze
        caches[database] = { stamp:, classes: }
        classes
      end

      def clear!
        @caches = {}
      end

      def version_key
        database = RailsMultisite::ConnectionManagement.current_db
        "discourse-workflows:node-packs:runtime-version:#{database}"
      end

      def caches
        @caches ||= {}
      end
    end
  end
end
