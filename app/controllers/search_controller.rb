require_dependency 'search'

class SearchController < ApplicationController

  def query
    render_json_dump(Search.query(params[:term], params[:type_filter]).as_json)
  end

end
