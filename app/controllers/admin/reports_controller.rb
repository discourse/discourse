require_dependency 'report'

class Admin::ReportsController < Admin::AdminController

  def show
    report_type = params[:type]

    raise Discourse::NotFound.new unless report_type =~ /^[a-z0-9\_]+$/

    start_date = 1.month.ago
    start_date = Time.parse(params[:start_date]) if params[:start_date].present?

    end_date = start_date + 1.month
    end_date = Time.parse(params[:end_date]) if params[:end_date].present?

    report = Report.find(report_type, {start_date: start_date, end_date: end_date})
    raise Discourse::NotFound.new if report.blank?

    render_json_dump(report: report)
  end

end
