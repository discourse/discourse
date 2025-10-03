# frozen_string_literal: true

class OneboxController < ApplicationController
  requires_login

  def show
    unless params[:refresh] == "true"
      preview = Oneboxer.cached_preview(params[:url])
      preview = preview.strip if preview.present?
      return render(plain: preview) if preview.present?
    end

    # only 1 outgoing preview per user
    return render(body: nil, status: 429) if Oneboxer.is_previewing?(current_user.id)

    user_id = current_user.id
    category_id = params[:category_id].to_i
    topic_id = params[:topic_id].to_i
    invalidate = params[:refresh] == "true"
    url = params[:url]

    return render(body: nil, status: 404) if Oneboxer.recently_failed?(url)

    hijack(info: "#{url} topic_id: #{topic_id} user_id: #{user_id}") do
      Oneboxer.preview_onebox!(user_id)

      preview =
        Oneboxer.preview(
          url,
          invalidate_oneboxes: invalidate,
          user_id: user_id,
          category_id: category_id,
          topic_id: topic_id,
        )

      preview = preview.strip if preview.present?

      Oneboxer.onebox_previewed!(user_id)

      if preview.blank?
        Oneboxer.cache_failed!(url)
        render body: nil, status: 404
      else
        render plain: preview
      end
    end
  end
end
