# frozen_string_literal: true

module JsonApiKit
  class BaseController < EndpointController
    include Fetching
    include RequestInput
  end
end
