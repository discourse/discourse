# frozen_string_literal: true

class ForumsController < ActionController::Base
  def status
    if $shutdown
      render plain: 'shutting down', status: 500
    else
      render plain: 'ok'
    end
  end

end
