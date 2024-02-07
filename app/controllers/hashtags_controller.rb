# frozen_string_literal: true

class HashtagsController < ApplicationController
  # Anonymous users can still see public posts which may contain hashtags
  requires_login except: [:by_ids]

  def by_ids
    raise Discourse::NotFound if SiteSetting.login_required? && !current_user

    render json: HashtagAutocompleteService.new(guardian).find_by_ids(params)
  end

  def lookup
    render json: HashtagAutocompleteService.new(guardian).lookup(params[:slugs], params[:order])
  end

  def search
    params.require(:order)

    results = HashtagAutocompleteService.new(guardian).search(params[:term], params[:order])

    render json: success_json.merge(results: results)
  end
end
