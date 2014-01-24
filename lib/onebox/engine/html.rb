module Onebox
  module Engine
    module HTML
      private

      # Overwrite for any custom headers
      def http_params
        {}
      end

      def raw
        @raw ||= Nokogiri::HTML(open(url, {read_timeout: timeout}.merge(http_params)).read)
      end

      def html?
        raw.respond_to(:css)
      end
    end
  end
end
