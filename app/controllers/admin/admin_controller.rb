class Admin::AdminController < ApplicationController

  before_filter :ensure_logged_in
  before_filter :ensure_staff

  def index
    render nothing: true
  end

  protected

  # this is not really necessary cause the routes are secure
  def ensure_staff
    raise Discourse::InvalidAccess.new unless current_user.staff?
  end

end
