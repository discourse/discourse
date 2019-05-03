# frozen_string_literal: true

require "read_only"

class ForumsController < ActionController::Base
  include ReadOnly

  before_action :check_readonly_mode
  after_action  :add_readonly_header

  def status
    if $shutdown
      render plain: 'shutting down', status: 500
    else
      render plain: 'ok'
    end
  end

end
