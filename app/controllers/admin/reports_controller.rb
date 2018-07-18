require_dependency 'report'

class Admin::ReportsController < Admin::AdminController
  def index
    reports_methods = Report.singleton_methods.grep(/^report_(?!about)/)

    reports = reports_methods.map do |name|
      type = name.to_s.gsub('report_', '')
      description = I18n.t("reports.#{type}.description", default: '')

      {
        type: type,
        title: I18n.t("reports.#{type}.title"),
        description: description.presence ? description : nil,
      }
    end

    render_json_dump(reports: reports.sort_by { |report| report[:title] })
  end

  def show
    report_type = params[:type]

    raise Discourse::NotFound unless report_type =~ /^[a-z0-9\_]+$/

    start_date = (params[:start_date].present? ? params[:start_date].to_date : 30.days.ago).beginning_of_day
    end_date = (params[:end_date].present? ? params[:end_date].to_date : start_date + 30.days).end_of_day

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

    facets = nil
    if Array === params[:facets]
      facets = params[:facets].map { |s| s.to_s.to_sym }
    end

    limit = nil
    if params.has_key?(:limit) && params[:limit].to_i > 0
      limit = params[:limit].to_i
    end

    args = {
      start_date: start_date,
      end_date: end_date,
      category_id: category_id,
      group_id: group_id,
      facets: facets,
      limit: limit
    }

    report = nil
    if (params[:cache])
      report = Report.find_cached(report_type, args)
    end

    if report
      return render_json_dump(report: report)
    end

    hijack do
      report = Report.find(report_type, args)

      raise Discourse::NotFound if report.blank?

      if (params[:cache])
        Report.cache(report, 35.minutes)
      end

      render_json_dump(report: report)
    end

  end

end
