# frozen_string_literal: true

class SrvController < ApplicationController
  skip_before_action :check_xhr,
                     :redirect_to_login_if_required,
                     :redirect_to_profile_if_required,
                     :preload_json,
                     :verify_authenticity_token

  def beacon_pv
    # Beacon pageview tracking is handled entirely by the RequestTracker
    # middleware. This action exists solely so that Rails generates request
    # logs for beacon requests.
  end
end
