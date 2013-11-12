# EXPERIMENTAL: front end for upgrading your instance using the web UI

class Admin::UpgradeController < Admin::AdminController

  before_filter :ensure_admin
  skip_before_filter :check_xhr

  layout 'no_js'

  def index
    require_dependency 'upgrade/git_repo'
    @main_repo = Upgrade::GitRepo.new(Rails.root)
  end

  protected

  def ensure_admin
    raise Discourse::InvalidAccess.new unless current_user.admin?
  end
end
