class Report

  attr_accessor :type, :data, :total, :prev30Days

  def initialize(type)
    @type = type
    @data = nil
    @total = nil
    @prev30Days = nil
  end

  def as_json
    {
     type: self.type,
     title: I18n.t("reports.#{self.type}.title"),
     xaxis: I18n.t("reports.#{self.type}.xaxis"),
     yaxis: I18n.t("reports.#{self.type}.yaxis"),
     data: self.data,
     total: self.total,
     prev30Days: self.prev30Days
    }
  end

  def self.find(type, opts={})
    report_method = :"report_#{type}"
    return nil unless respond_to?(report_method)

    # Load the report
    report = Report.new(type)
    send(report_method, report)
    report
  end

  def self.report_visits(report)
    basic_report_about report, UserVisit, :by_day
  end

  def self.report_signups(report)
    report_about report, User, :count_by_signup_date
  end

  def self.report_topics(report)
    report_about report, Topic, :listable_count_per_day
  end

  def self.report_posts(report)
    report_about report, Post, :public_posts_count_per_day
  end

  def self.report_private_messages(report)
    report_about report, Post, :private_messages_count_per_day
  end

  def self.report_emails(report)
    report_about report, EmailLog
  end

  def self.report_about(report, subject_class, report_method = :count_per_day)
    basic_report_about report, subject_class, report_method
    add_counts(report, subject_class)
  end

  def self.basic_report_about(report, subject_class, report_method)
    report.data = []
    subject_class.send(report_method, 30).each do |date, count|
      report.data << {x: date, y: count}
    end
  end

  def self.add_counts(report, subject_class)
    report.total      = subject_class.count
    report.prev30Days = subject_class.where('created_at > ? and created_at < ?', 60.days.ago, 30.days.ago).count
  end

  def self.report_flags(report)
    report.data = []
    (0..30).to_a.reverse.each do |i|
      if (count = PostAction.where('date(created_at) = ?', i.days.ago.to_date).where(post_action_type_id: PostActionType.flag_types.values).count) > 0
        report.data << {x: i.days.ago.to_date.to_s, y: count}
      end
    end
    flagsQuery = PostAction.where(post_action_type_id: PostActionType.flag_types.values)
    report.total = flagsQuery.count
    report.prev30Days = flagsQuery.where('created_at > ? and created_at < ?', 60.days.ago, 30.days.ago).count
  end

  def self.report_users_by_trust_level(report)
    report.data = []
    User.counts_by_trust_level.each do |level, count|
      report.data << {x: level.to_i, y: count}
    end
  end

  def self.report_likes(report)
    report.data = []
    PostAction.count_likes_per_day(30).each do |date, count|
      report.data << {x: date, y: count}
    end
    likesQuery = PostAction.where(post_action_type_id: PostActionType.types[:like])
    report.total = likesQuery.count
    report.prev30Days = likesQuery.where('created_at > ? and created_at < ?', 60.days.ago, 30.days.ago).count
  end
end
