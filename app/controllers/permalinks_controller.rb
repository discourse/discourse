class PermalinksController < ApplicationController
  skip_before_filter :check_xhr, :preload_json

  def show
    url = params[:url]
    url = "#{url}?#{request.query_string}" if request.query_string.present?
    permalink = Permalink.find_by_url(url)
    if permalink && permalink.target_url
      redirect_to permalink.target_url, status: :moved_permanently
    else
      raise Discourse::NotFound
    end
  end
end
