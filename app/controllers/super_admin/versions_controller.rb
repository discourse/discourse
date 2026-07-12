# frozen_string_literal: true

class SuperAdmin::VersionsController < SuperAdmin::StaffController
  def show
    render json: DiscourseUpdates.check_version
  end
end
