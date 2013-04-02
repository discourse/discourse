require_dependency 'search'

class SearchController < ApplicationController

  def query
    search_result = if guardian.can_search?
      Search.query(params[:term], params[:type_filter], SiteSetting.min_search_term_length)
    else
      []
    end
    render_json_dump(search_result.as_json)
  end

end
