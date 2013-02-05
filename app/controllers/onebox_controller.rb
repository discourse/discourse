require_dependency 'oneboxer'

class OneboxController < ApplicationController

  def show
    Oneboxer.invalidate(params[:url]) if params[:refresh].present?
    render text: Oneboxer.preview(params[:url])
  end

end
