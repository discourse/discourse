require_dependency 'search'

class SearchController < ApplicationController

  def query
    search_result = Search.query(params[:term], guardian, params[:type_filter], SiteSetting.min_search_term_length)
    render_json_dump(search_result.as_json)
  end

end
