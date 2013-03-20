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
    UserVisit.by_day(30.days.ago).each do |date, count|
      report.data << {x: date, y: count}
    end
  end

  def self.report_signups(report)
    report.data = []
    User.count_by_signup_date(30.days.ago).each do |date, count|
      report.data << {x: date, y: count}
    end
  end

  def self.report_topics(report)
    report.data = []
    Topic.count_per_day(30.days.ago).each do |date, count|
      report.data << {x: date, y: count}
    end
  end

  def self.report_posts(report)
    report.data = []
    Post.count_per_day(30.days.ago).each do |date, count|
      report.data << {x: date, y: count}
    end
  end

  def self.report_flags(report)
    report.data = []
    (0..30).to_a.reverse.each do |i|
      if (count = PostAction.where('date(created_at) = ?', i.days.ago.to_date).where(post_action_type_id: PostActionType.flag_types.values).count) > 0
        report.data << {x: i.days.ago.to_date.to_s, y: count}
      end
    end
  end

  def self.report_users_by_trust_level(report)
    report.data = []
    User.counts_by_trust_level.each do |level, count|
      report.data << {x: level.to_i, y: count}
    end
  end

  def self.report_likes(report)
    report.data = []
    PostAction.count_likes_per_day(30.days.ago).each do |date, count|
      report.data << {x: date, y: count}
    end
  end

  def self.report_emails(report)
    report.data = []
    EmailLog.count_per_day(30.days.ago).each do |date, count|
      report.data << {x: date, y: count}
    end
  end

end
