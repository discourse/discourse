require_dependency 'search'

class SearchController < ApplicationController

  def query
    search_result = if current_user.blank? && SiteSetting.site_requires_login?
      []
    else
      Search.query(params[:term], params[:type_filter], SiteSetting.min_search_term_length)
    end
    render_json_dump(search_result.as_json)
  end

end
