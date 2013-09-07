module Onebox
  module Engine
    module HTML
      private

      def raw
        @raw ||= Nokogiri::HTML(open(@url))
      end
    end
  end
end
