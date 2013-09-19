module Onebox
  module Engine
    module JSON
      private

      def raw
        @raw ||= ::MultiJson.load(open(@url))
      end
    end
  end
end
