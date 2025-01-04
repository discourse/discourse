# frozen_string_literal: true

class OfflineController < ApplicationController
  layout false
  skip_before_action :check_xhr, :redirect_to_login_if_required, :redirect_to_profile_if_required

  def index
    render :offline, content_type: "text/html"
  end
end
