# frozen_string_literal: true

module JsonApiKit
  class EndpointController < ::ApplicationController
    skip_before_action :check_xhr,
                       :redirect_to_login_if_required,
                       :verify_authenticity_token,
                       raise: false

    # Order matters here
    include Rendering
    include Negotiating
    include Versioning
    include Serving
    include ClientContext
  end
end
