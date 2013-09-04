module Onebox
  module Engine
    module OpenGraph
      def raw
        @raw ||= ::OpenGraph.new(@url)
      end
    end
  end
end
