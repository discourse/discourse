class ForumsController < ApplicationController

  skip_before_filter :check_xhr, only: [:status]
  skip_before_filter :authorize_mini_profiler, only: [:status]
  skip_before_filter :redirect_to_login_if_required, only: [:status]

  def status
    if $shutdown
      render text: 'shutting down', status: 500
    else
      render text: 'ok'
    end
  end

  def error
    raise "WAT - #{Time.now.to_s}"
  end

end
