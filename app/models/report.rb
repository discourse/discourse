class Report

  attr_accessor :type, :data

  def initialize(type)
    @type = type
    @data = nil
  end

  def as_json
    {
     type: self.type,
     title: I18n.t("reports.#{self.type}.title"),
     xaxis: I18n.t("reports.#{self.type}.xaxis"),
     yaxis: I18n.t("reports.#{self.type}.yaxis"),
     data: self.data
    }
  end

  def self.find(type)
    report_method = :"report_#{type}"
    return nil unless respond_to?(report_method)

    # Load the report
    report = Report.new(type)
    send(report_method, report)
    report
  end

  def self.report_visits(report)
    report.data = []
    UserVisit.by_day.each do |date, count|
      report.data << {x: date, y: count}
    end
  end

end
