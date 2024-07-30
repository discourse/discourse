# frozen_string_literal: true

module NetHTTPPatch
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 10
  WRITE_TIMEOUT = 5

  # By default Net::HTTP will retry 1 time on idempotent requests but we can't afford that while processing a request
  # so setting it to 0
  MAX_RETIRES = 0

  def initialize(*args, &block)
    super(*args, &block)

    ## START PATCH
    if Thread.current[Middleware::ProcessingRequest::PROCESSING_REQUEST_THREAD_KEY]
      self.open_timeout = OPEN_TIMEOUT
      self.read_timeout = READ_TIMEOUT
      self.write_timeout = WRITE_TIMEOUT
      self.max_retries = 0
    end
    ## END PATCH
  end
end

Net::HTTP.prepend(NetHTTPPatch)
