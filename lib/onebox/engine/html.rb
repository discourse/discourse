module Onebox
  module Engine
    module HTML
      private

      def raw
        @raw ||= Nokogiri::HTML(open(url, read_timeout: timeout))
      end
    end
  end
end
