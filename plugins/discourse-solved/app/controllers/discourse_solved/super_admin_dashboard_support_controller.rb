# frozen_string_literal: true

class DiscourseSolved::SuperAdminDashboardSupportController < ::SuperAdmin::StaffController
  requires_plugin DiscourseSolved::PLUGIN_NAME

  def index
    render json:
             DiscourseSolved::AdminDashboardSupport.build(
               start_date: params[:start_date],
               end_date: params[:end_date],
               current_user: current_user,
               category_id: params[:category_id],
             )
  end
end
