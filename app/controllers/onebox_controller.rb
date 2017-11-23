require_dependency 'oneboxer'

class OneboxController < ApplicationController
  before_action :ensure_logged_in

  def show

    unless params[:refresh] == 'true'
      preview = Oneboxer.cached_preview(params[:url])
      preview.strip! if preview.present?
      return render(plain: preview) if preview.present?
    end

    # only 1 outgoing preview per user
    return render(body: nil, status: 429) if Oneboxer.is_previewing?(current_user.id)

    Oneboxer.preview_onebox!(current_user.id)

    preview = Oneboxer.preview(params[:url], invalidate_oneboxes: params[:refresh] == 'true')
    preview.strip! if preview.present?

    Scheduler::Defer.later("Onebox previewed") {
      Oneboxer.onebox_previewed!(current_user.id)
    }

    if preview.blank?
      render body: nil, status: 404
    else
      render plain: preview
    end
  end

end
