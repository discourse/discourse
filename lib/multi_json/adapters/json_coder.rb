# frozen_string_literal: true

module MultiJson
  module Adapters
    class JsonCoder < JsonGem
      CODER = JSON::Coder.new(&:as_json)

      def dump(object, options)
        CODER.dump(object)
      end
    end
  end
end
