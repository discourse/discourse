# frozen_string_literal: true

module MultiJson
  module Adapters
    class JsonCoder < JsonGem
      CODER =
        JSON::Coder.new do |object|
          case object
          when ActiveSupport::SafeBuffer
            object.to_str
          else
            object.as_json
          end
        end

      def dump(object, options)
        CODER.dump(object)
      end
    end
  end
end
