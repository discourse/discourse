module Onebox
  module Engine
    module OpenGraph
      private

      def raw
        return @raw if @raw
        response = fetch_response(url)
        @raw = ::OpenGraph.new(response.body)
      end

      def fetch_response(location, limit = 3)
        # You should choose better exception.
        fail ArgumentError, 'HTTP redirect too deep' if limit == 0

        response = Net::HTTP.get_response(URI(location))
        case response
        when Net::HTTPSuccess     then response
        when Net::HTTPRedirection then fetch_response(response['location'], limit - 1)
        else
          response.error!
        end
      end
    end
  end
end
