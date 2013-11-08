module Onebox
  module Engine
    module HTML
      private

      def raw
        @raw ||= Nokogiri::HTML(open(url, read_timeout: timeout))
      end

      def html?
        raw.respond_to(:css)
      end
    end
  end
end
