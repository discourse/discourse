# frozen_string_literal: true

require "read_only_header"

class ForumsController < ActionController::Base
  include ReadOnlyHeader

  before_action :check_readonly_mode
  after_action  :add_readonly_header

  def status
    if $shutdown # rubocop:disable Style/GlobalVars
      render plain: "shutting down", status: 500
    else
      render plain: "ok"
    end
  end

end
