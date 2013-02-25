class RateLimiter

  # A rate limit has been exceeded.
  class LimitExceeded < Exception
    attr_accessor :available_in
    def initialize(available_in)
      @available_in = available_in
    end
  end

end
