# frozen_string_literal: true

module Categories
  class TypeRegistry
    COUNTS_CACHE_KEY = "category_type_counts"

    class << self
      def register(klass, plugin_identifier: nil)
        id = klass.type_id
        unless id.to_s.match?(/\A[a-z0-9_]+\z/)
          raise ArgumentError,
                "Category type_id '#{id}' must only contain lowercase letters, digits, and underscores"
        end
        if types.key?(id) && owners[id] != plugin_identifier
          raise ArgumentError,
                "Category type '#{id}' is already registered#{owners[id] ? " by #{owners[id]}" : ""}"
        end
        types[id] = klass
        owners[id] = plugin_identifier
      end

      def get(id)
        types[id.to_sym]
      end

      def get!(id)
        get(id) || raise(ArgumentError, "Unknown category type: #{id}")
      end

      def all
        types
      end

      def list(only_visible: false)
        types.values.select { |type| only_visible ? type.visible? : true }.map(&:metadata)
      end

      def valid?(id)
        types.key?(id.to_sym)
      end

      def reset!
        @types = nil
        @owners = nil

        # Always need to re-register the core Discussion type, the system doesn't work
        # without it.
        self.register(Categories::Types::Discussion)
      end

      # Returns all the category type counts in a hash with the type
      # and count like this:
      #
      # {
      #   discussion: 10,
      #   support: 5,
      # }
      #
      # Relies on the find_matches method overriden by each category type
      # to return an AR relation that will be used to count the categories.
      def counts
        type_list = types.values
        return {} if type_list.empty?

        # We want to get all the counts in a single query to avoid N1
        conn = Category.connection
        select_parts =
          type_list.map do |type|
            subquery_sql = type.find_matches.select("COUNT(*)").to_sql
            alias_name = conn.quote_column_name(type.type_id.to_s)
            "(#{subquery_sql}) AS #{alias_name}"
          end
        result = conn.select_one("SELECT #{select_parts.join(", ")}")
        type_list.each_with_object({}) do |type, counts|
          counts[type.type_id] = (result[type.type_id.to_s] || 0).to_i
        end
      end

      private

      def types
        @types ||= {}
      end

      def owners
        @owners ||= {}
      end
    end
  end
end
