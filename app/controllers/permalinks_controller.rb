# frozen_string_literal: true

class PermalinksController < ApplicationController
  skip_before_action :check_xhr, only: [:show]

  def show
    url = request.fullpath

    permalink = Permalink.find_by_url(url)

    raise Discourse::NotFound unless permalink

    if permalink.target_url
      redirect_to permalink.target_url, status: :moved_permanently, allow_other_host: true
    else
      raise Discourse::NotFound
    end
  end

  def check
    begin
      raise Discourse::NotFound if params[:path].blank?

      permalink = Permalink.find_by_url(params[:path])

      raise Discourse::NotFound unless permalink

      data = {
        found: true,
        internal: permalink.external_url.nil?,
        target_url: permalink.target_url,
      }

      render json: MultiJson.dump(data)
    rescue Discourse::NotFound
      data = { found: false, html: build_not_found_page(status: 200) }
      render json: MultiJson.dump(data)
    end
  end
end
