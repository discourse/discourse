require_dependency 'search'

class SearchController < ApplicationController

  def query
    search = Search.new(params[:term],
                        guardian: guardian,
                        type_filter: params[:type_filter])

    render_json_dump(search.execute.as_json)
  end

end
