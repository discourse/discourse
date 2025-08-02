# frozen_string_literal: true

class InlineOneboxController < ApplicationController
  MAX_URLS_LIMIT = 10

  requires_login

  def show
    urls = params[:urls] || []

    if urls.size > MAX_URLS_LIMIT
      render json: failed_json.merge(errors: [I18n.t("inline_oneboxer.too_many_urls")]), status: 413
      return
    end

    current_user_id = current_user.id

    if InlineOneboxer.is_previewing?(current_user_id)
      response.headers["Retry-After"] = "60"
      render json: failed_json.merge(errors: [I18n.t("inline_oneboxer.concurrency_not_allowed")]),
             status: 429
      return
    end

    hijack do
      InlineOneboxer.preview!(current_user_id)

      oneboxes =
        InlineOneboxer.new(
          params[:urls] || [],
          user_id: current_user.id,
          category_id: params[:category_id].to_i,
          topic_id: params[:topic_id].to_i,
        ).process

      InlineOneboxer.finish_preview!(current_user_id)
      render json: { "inline-oneboxes" => oneboxes }
    end
  end
end
