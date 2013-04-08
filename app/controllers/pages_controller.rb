class PagesController < ApplicationController
  
  skip_before_filter :check_xhr
    
  def show
    @pages = Page.all
    @current_page = Page.find(params[:id])
    render 'pages/show', layout: !request.xhr?, formats: [:html]
  end

end
