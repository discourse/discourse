class Admin::SearchLogsController < Admin::AdminController

  def index
    period = params[:period] || "all"
    search_type = params[:search_type] || "all"
    render_serialized(SearchLog.trending(period&.to_sym, search_type&.to_sym), SearchLogsSerializer)
  end

end
