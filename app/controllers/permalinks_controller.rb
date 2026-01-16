# frozen_string_literal: true

class PermalinksController < ApplicationController
  skip_before_action :check_xhr, :preload_json, only: [:show]

  def show
    permalink = Permalink.find_by_url(request.fullpath)

    raise Discourse::NotFound if permalink.nil?
    raise Discourse::NotFound unless guardian.can_see_permalink_target?(permalink)

    if permalink.target_url
      redirect_to permalink.target_url, status: :moved_permanently, allow_other_host: true
    else
      raise Discourse::NotFound
    end
  end

  def check
    permalink = Permalink.find_by_url(params[:path]) if params[:path].present?

    data =
      if permalink && guardian.can_see_permalink_target?(permalink)
        { found: true, internal: permalink.internal?, target_url: permalink.target_url }
      else
        { found: false, html: build_not_found_page(status: 200) }
      end

    render json: MultiJson.dump(data)
  end
end
