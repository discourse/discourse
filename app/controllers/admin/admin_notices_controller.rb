# frozen_string_literal: true

class Admin::AdminNoticesController < Admin::StaffController
  def destroy
    AdminNotices::Dismiss.call(service_params) do
      on_success { render(json: success_json) }
      on_failure { render(json: failed_json, status: 422) }
    end
  end
end
