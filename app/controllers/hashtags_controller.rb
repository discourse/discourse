# frozen_string_literal: true

class HashtagsController < ApplicationController
  requires_login

  def show
    raise Discourse::InvalidParameters.new(:slugs) if !params[:slugs].is_a?(Array)
    render json: HashtagService.new(guardian).load_from_slugs(params[:slugs])
  end

  def search
    params.require(:term)
    params.require(:order)
    raise Discourse::InvalidParameters.new(:order) if !params[:order].is_a?(Array)

    results = HashtagService.new(guardian).search(params[:term], params[:order])

    render json: success_json.merge(results: results)
  end
end
