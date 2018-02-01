class Admin::AdminController < ApplicationController

  prepend_before_action :check_xhr, :ensure_logged_in
  prepend_before_action :check_xhr, :ensure_staff

  def index
    render body: nil
  end

end
