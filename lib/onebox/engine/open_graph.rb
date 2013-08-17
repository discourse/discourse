module Onebox
  module Engine
    module OpenGraph
      include Engine

      def read
        ::OpenGraph.new(@url)
      end
    end
  end
end
