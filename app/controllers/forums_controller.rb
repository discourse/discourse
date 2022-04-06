# frozen_string_literal: true

require "read_only_header"

class ForumsController < ActionController::Base
  include ReadOnlyHeader

  before_action :check_readonly_mode
  after_action  :add_readonly_header

  def status
    if params[:cluster]
      if GlobalSetting.cluster_name.nil?
        return render plain: "cluster name not configured", status: 500
      elsif GlobalSetting.cluster_name != params[:cluster]
        return render plain: "cluster name does not match", status: 500
      end
    end

    render plain: "ok"
  end
end
