# frozen_string_literal: true

class Admin::VersionsController < Admin::AdminController
  def show
    render json: DiscourseUpdates.check_version
  end
end
