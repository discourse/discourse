require_dependency 'report'

class Admin::ReportsController < Admin::AdminController

  def show

    report_type = params[:type]

    raise Discourse::NotFound.new unless report_type =~ /^[a-z0-9\_]+$/

    report = Report.find(report_type)
    raise Discourse::NotFound.new if report.blank?

    render_json_dump(report: report)
  end

end
