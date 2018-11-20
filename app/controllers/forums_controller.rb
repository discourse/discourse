# frozen_string_literal: true

class ForumsController < ApplicationController

  skip_before_action :preload_json, :check_xhr
  skip_before_action :authorize_mini_profiler, only: [:status]
  skip_before_action :redirect_to_login_if_required, only: [:status]

  def status
    if $shutdown
      render plain: 'shutting down', status: 500
    else
      render plain: 'ok'
    end
  end

end
