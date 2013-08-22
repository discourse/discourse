module Onebox
  module Engine
    module OpenGraph
      def read
        ::OpenGraph.new(@url)
      end
    end
  end
end
