module Definitions
  module Errors
    class Error < StandardError; end
    class NoMonths < Error ; end
    class InvalidMonth < Error; end
    class InvalidMethod < Error; end
    class InvalidRegions < Error; end
    class InvalidCustomMethod < Error; end
    class InvalidTest < Error; end
  end
end
