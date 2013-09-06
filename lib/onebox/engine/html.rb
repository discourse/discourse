module Onebox
  module Engine
    module HTML
      private

      def raw
        @raw ||= ::OpenGraph.new(@url)
      end
    end
  end
end
