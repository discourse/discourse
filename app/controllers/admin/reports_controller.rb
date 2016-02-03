require_dependency 'report'

class Admin::ReportsController < Admin::AdminController

  def show
    report_type = params[:type]

    raise Discourse::NotFound unless report_type =~ /^[a-z0-9\_]+$/

    start_date = 1.month.ago
    start_date = Time.parse(params[:start_date]) if params[:start_date].present?

    end_date = start_date + 1.month
    end_date = Time.parse(params[:end_date]) if params[:end_date].present?

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
