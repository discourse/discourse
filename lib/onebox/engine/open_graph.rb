module Onebox
  module Engine
    module OpenGraph
      private

      def raw
        @raw ||= ::OpenGraph.new(url)
      end
    end
  end
end
