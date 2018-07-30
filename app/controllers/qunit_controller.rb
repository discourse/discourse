class QunitController < ApplicationController
  skip_before_action :check_xhr, :preload_json
  layout false

  # only used in test / dev
  def index
    raise Discourse::InvalidAccess.new if Rails.env.production?
  end

  # make nonce static and set restrictive csp for testing
  def set_csp_header
    request.env["nonce"] = "1234"
    response.headers["Content-Security-Policy"] = "script-src 'nonce-1234' 'unsafe-eval';"
  end
end
