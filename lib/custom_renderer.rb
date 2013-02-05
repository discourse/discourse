class CustomRenderer < AbstractController::Base
  include ActiveSupport::Configurable
  include AbstractController::Rendering
  include AbstractController::Helpers
  include AbstractController::Translation
  include AbstractController::AssetPaths
  include Rails.application.routes.url_helpers
  helper ApplicationHelper
  self.view_paths = "app/views"
  include CurrentUser

  def action_name
    ""
  end

  def controller_name
    ""
  end

  def cookies
    @parent.send(:cookies)
  end

  def session
    @parent.send(:session)
  end

  def initialize(parent)
    @parent = parent
  end
end
