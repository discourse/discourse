unless rails4?
  module ActiveRecord
    class Relation
      # Patch Rails 3 ActiveRecord::Relation to noop on Rails 4 references
      # thereby getting code that works for rails 3 and 4 without
      # deprecation warnings

      def references(*args)
        self
      end

    end
  end
end
