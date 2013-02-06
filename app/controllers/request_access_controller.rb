class RequestAccessController < ApplicationController

  skip_before_filter :check_xhr, :check_restricted_access

  def new
    @return_path = params[:return_path] || "/"
    render layout: 'no_js'
  end

  def create
    @return_path = params[:return_path] || "/"

    if params[:password] == SiteSetting.access_password
      cookies.permanent['_access'] = SiteSetting.access_password
      redirect_to @return_path
    else
      flash[:error] = I18n.t(:'request_access.incorrect')
      render :new, layout: 'no_js'
    end
  end

end
