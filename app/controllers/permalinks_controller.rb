# frozen_string_literal: true

class PermalinksController < ApplicationController
  skip_before_action :check_xhr, :preload_json

  def show
    url = request.fullpath

    if url.start_with?('/go/')
      permalink = Permalink.match_go(url).first
      raise Discourse::NotFound unless permalink

      given = URI.parse(url)
      path_suffix = Permalink.normalize_basic(given.path).delete_prefix(permalink.url).delete_prefix('/')

      # Short circuit: Nothing special in the request
      # TODO(riking): enable once features are settled
      # return redirect_to(permalink.target_url, status: 302) if path_suffix.blank? && given.query.blank?

      target = URI.parse(permalink.target_url)

      if !path_suffix.blank?
        target.path = (target.path.delete_suffix('/')) + '/' + path_suffix
      end

      if given.query
        given_query = Rack::Utils.parse_query(given.query)
        target_query = Rack::Utils.parse_query(target.query)
        target.query = target_query.merge(given_query).to_query
      end

      redirect_to target.to_s, status: 302
      return
    end

    permalink = Permalink.find_by_url(url)

    raise Discourse::NotFound unless permalink

    if permalink.target_url
      redirect_to permalink.target_url, status: :moved_permanently
    else
      raise Discourse::NotFound
    end
  end

end
