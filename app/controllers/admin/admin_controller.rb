class Admin::AdminController < ApplicationController

  before_action :ensure_logged_in
  before_action :ensure_staff

  def index
    render body: nil
  end

end
