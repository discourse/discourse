class PermalinksController < ApplicationController
  skip_before_filter :check_xhr, :preload_json

  def show
    url = request.fullpath

    permalink = Permalink.find_by_url(url)

    raise Discourse::NotFound unless permalink

    if permalink.external_url
      redirect_to permalink.external_url, status: :moved_permanently
    elsif permalink.target_url
      redirect_to "#{Discourse::base_uri}#{permalink.target_url}", status: :moved_permanently
    else
      raise Discourse::NotFound
    end
  end

end
