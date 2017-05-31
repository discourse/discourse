require_dependency 'report'

class Admin::ReportsController < Admin::AdminController

  def show
    report_type = params[:type]

    raise Discourse::NotFound unless report_type =~ /^[a-z0-9\_]+$/

    start_date = params[:start_date].present? ? Time.parse(params[:start_date]) : 30.days.ago
    end_date = params[:end_date].present? ? Time.parse(params[:end_date]) : start_date + 30.days

    if params.has_key?(:category_id) && params[:category_id].to_i > 0
      category_id = params[:category_id].to_i
    else
      category_id = nil
    end

    if params.has_key?(:group_id) && params[:group_id].to_i > 0
      group_id = params[:group_id].to_i
    else
      group_id = nil
    end

    report = Report.find(report_type, start_date: start_date, end_date: end_date, category_id: category_id, group_id: group_id)

    raise Discourse::NotFound if report.blank?

    render_json_dump(report: report)
  end

end
