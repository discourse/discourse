class ForumsController < ApplicationController

  skip_before_filter :preload_json, :check_xhr
  skip_before_filter :authorize_mini_profiler, only: [:status]
  skip_before_filter :redirect_to_login_if_required, only: [:status]

  def status
    if $shutdown
      render text: 'shutting down', status: 500, content_type: 'text/plain'
    else
      render text: 'ok', content_type: 'text/plain'
    end
  end

  def error
    raise "WAT - #{Time.now}"
  end

  def home_redirect
    redirect_to path('/')
  end

end
