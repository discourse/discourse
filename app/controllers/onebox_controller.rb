require_dependency 'oneboxer'

class OneboxController < ApplicationController

  def show
    Oneboxer.invalidate(params[:url]) if params[:refresh].present?

    result = Oneboxer.preview(params[:url])
    result.strip! if result.present?

    # If there is no result, return a 404
    if result.blank?
      render nothing: true, status: 404
    else
      render text: result
    end
  end

end
