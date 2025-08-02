# frozen_string_literal: true

class Admin::VersionsController < Admin::StaffController
  def show
    render json: DiscourseUpdates.check_version
  end
end
