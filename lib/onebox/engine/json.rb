module Onebox
  module Engine
    module JSON
      private

      def raw
        @raw ||= ::MultiJson.load(open(url, read_timeout: timeout))
      end
    end
  end
end
