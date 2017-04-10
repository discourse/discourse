require_dependency 'oneboxer'

class OneboxController < ApplicationController
  before_filter :ensure_logged_in

  def show
    params.require(:user_id)

    preview = Oneboxer.cached_preview(params[:url])
    preview.strip! if preview.present?

    return render(plain: preview) if preview.present?

    # only 1 outgoing preview per user
    return render(nothing: true, status: 429) if Oneboxer.is_previewing?(params[:user_id])

    Oneboxer.preview_onebox!(params[:user_id])

    preview = Oneboxer.preview(params[:url], invalidate_oneboxes: params[:refresh] == 'true')
    preview.strip! if preview.present?

    Scheduler::Defer.later("Onebox previewed") {
      Oneboxer.onebox_previewed!(params[:user_id])
    }

    if preview.blank?
      render nothing: true, status: 404
    else
      render plain: preview
    end
  end

end
