# frozen_string_literal: true
module PageObjects
  module Native
    class SlowUpload
      def initialize(page)
        @page = page
      end

      def during
        session = @page.context.new_cdp_session(@page)
        session.send_message(
          "Network.emulateNetworkConditions",
          params: {
            offline: false,
            latency: 0,
            downloadThroughput: -1,
            uploadThroughput: 1,
          },
        )
        yield
      ensure
        session.send_message(
          "Network.emulateNetworkConditions",
          params: {
            offline: false,
            latency: 0,
            downloadThroughput: -1,
            uploadThroughput: -1,
          },
        )
      end
    end
  end
end
