require_dependency 'oneboxer'

class OneboxController < ApplicationController

  def show
    result = Oneboxer.preview(params[:url], invalidate_oneboxes: params[:refresh] == 'true')
    result.strip! if result.present?

    # If there is no result, return a 404
    if result.blank?
      render nothing: true, status: 404
    else
      render text: result
    end
  end

end
