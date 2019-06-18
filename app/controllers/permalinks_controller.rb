# frozen_string_literal: true

class PermalinksController < ApplicationController
  skip_before_action :check_xhr, :preload_json

  def show
    url = request.fullpath

    permalink = Permalink.find_by_url(url)

    raise Discourse::NotFound unless permalink

    if permalink.target_url
      redirect_to permalink.target_url, status: :moved_permanently
    else
      raise Discourse::NotFound
    end
  end

end
