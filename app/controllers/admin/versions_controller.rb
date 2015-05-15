require_dependency 'discourse_updates'

class Admin::VersionsController < Admin::AdminController
  def show
    render json: DiscourseUpdates.check_version
  end
end
