# frozen_string_literal: true

module JsonApiKit
  class Request
    class Collection < Request
      def scope(from:) = from
    end
  end
end
