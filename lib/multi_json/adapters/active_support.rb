# frozen_string_literal: true

module MultiJson
  module Adapters
    class ActiveSupport < Adapter
      ParseError = ::JSON::ParserError

      def load(string, options = {})
        ::ActiveSupport::JSON.decode(string)
      end

      def dump(object, options = {})
        ::ActiveSupport::JSON.encode(object, options)
      end
    end
  end
end
