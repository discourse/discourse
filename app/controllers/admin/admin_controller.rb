class Admin::AdminController < ApplicationController

  before_filter :ensure_logged_in
  before_filter :ensure_is_admin

  def index
    render nothing: true
  end

  protected

    def ensure_is_admin
      raise Discourse::InvalidAccess.new unless current_user.admin?
    end

end
