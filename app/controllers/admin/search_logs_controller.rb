class Admin::SearchLogsController < Admin::AdminController

  def index
    period = params[:period] || "all"
    search_type = params[:search_type] || "all"
    render_serialized(SearchLog.trending(period&.to_sym, search_type&.to_sym), SearchLogsSerializer)
  end

  def term
    params.require(:term)

    term = params[:term]
    period = params[:period] || "quarterly"
    search_type = params[:search_type] || "all"

    details = SearchLog.term_details(term, period&.to_sym, search_type&.to_sym)
    raise Discourse::NotFound if details.blank?

    render_json_dump(term: details)
  end

end
