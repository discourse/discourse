class Report

  attr_accessor :type, :data, :cache

  def self.cache_expiry
    3600  # In seconds
  end

  def initialize(type)
    @type = type
    @data = nil
    @cache = true
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

  def self.find(type, opts={})
    report_method = :"report_#{type}"
    return nil unless respond_to?(report_method)

    # Load the report
    report = Report.new(type)
    report.cache = false if opts[:cache] == false
    send(report_method, report)
    report
  end

  def self.report_visits(report)
    report.data = []
    fetch report do
      UserVisit.by_day(30.days.ago).each do |date, count|
        report.data << {x: date, y: count}
      end
    end
  end

  def self.report_signups(report)
    report.data = []
    fetch report do
      User.count_by_signup_date(30.days.ago).each do |date, count|
        report.data << {x: date, y: count}
      end
    end
  end

  def self.report_topics(report)
    report.data = []
    fetch report do
      Topic.count_per_day(30.days.ago).each do |date, count|
        report.data << {x: date, y: count}
      end
    end
  end

  def self.report_posts(report)
    report.data = []
    fetch report do
      Post.count_per_day(30.days.ago).each do |date, count|
        report.data << {x: date, y: count}
      end
    end
  end


  private

    def self.fetch(report)
      unless report.cache and $redis
        yield
        return
      end

      data_set = "#{report.type}:data"
      if $redis.exists(data_set)
        $redis.get(data_set).split('|').each do |pair|
          date, count = pair.split(',')
          report.data << {x: date, y: count.to_i}
        end
      else
        yield
        $redis.setex data_set, cache_expiry, report.data.map { |item| "#{item[:x]},#{item[:y]}" }.join('|')
      end
    rescue Redis::BaseConnectionError
      yield
    end

end
