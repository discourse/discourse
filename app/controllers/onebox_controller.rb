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

    user_id = current_user.id
    invalidate = params[:refresh] == 'true'
    url = params[:url]

    hijack do
      Oneboxer.preview_onebox!(user_id)

      preview = Oneboxer.preview(url, invalidate_oneboxes: invalidate)
      preview.strip! if preview.present?

      Oneboxer.onebox_previewed!(user_id)

      if preview.blank?
        render body: nil, status: 404
      else
        render plain: preview
      end
    end
  end

end
