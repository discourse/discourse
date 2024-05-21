# frozen_string_literal: true

class Admin::FlagsController < Admin::StaffController
  def toggle
    guardian.ensure_can_toggle_flag!
    flag = Flag.find(params[:flag_id])
    flag.update!(enabled: !flag.enabled)

    Discourse.request_refresh!
    render json: success_json
  end

  def index
  end
end
