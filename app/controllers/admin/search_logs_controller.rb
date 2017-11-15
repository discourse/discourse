class Admin::SearchLogsController < Admin::AdminController

  def index
    period = params[:period] || "all"
    render_serialized(SearchLog.trending(period.to_sym), SearchLogsSerializer)
  end

end
