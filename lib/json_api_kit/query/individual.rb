# frozen_string_literal: true

module JsonApiKit
  class Query
    class Individual < Query
      def record
        records.first or raise NotFound
      end
    end
  end
end
