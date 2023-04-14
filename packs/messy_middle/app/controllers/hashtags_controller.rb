# frozen_string_literal: true

class HashtagsController < ApplicationController
  requires_login

  def lookup
    if SiteSetting.enable_experimental_hashtag_autocomplete
      render json: HashtagAutocompleteService.new(guardian).lookup(params[:slugs], params[:order])
    else
      render json: HashtagAutocompleteService.new(guardian).lookup_old(params[:slugs])
    end
  end

  def search
    params.require(:order)

    results = HashtagAutocompleteService.new(guardian).search(params[:term], params[:order])

    render json: success_json.merge(results: results)
  end
end
