require_dependency 'topic_subtype'

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
    basic_report_about report, Topic, :listable_count_per_day
    report.total = Topic.listable_topics.count
    report.prev30Days = Topic.listable_topics.where('created_at > ? and created_at < ?', 60.days.ago, 30.days.ago).count
  end

  def self.report_posts(report)
    basic_report_about report, Post, :public_posts_count_per_day
    report.total = Post.public_posts.count
    report.prev30Days = Post.public_posts.where('posts.created_at > ? and posts.created_at < ?', 60.days.ago, 30.days.ago).count
  end

  def self.report_emails(report)
    report_about report, EmailLog
  end

  def self.report_about(report, subject_class, report_method = :count_per_day)
    basic_report_about report, subject_class, report_method
    add_counts(report, subject_class)
  end

  def self.basic_report_about(report, subject_class, report_method, *args)
    report.data = []
    subject_class.send(report_method, 30, *args).each do |date, count|
      report.data << {x: date, y: count}
    end
  end

  def self.add_counts(report, subject_class)
    report.total      = subject_class.count
    report.prev30Days = subject_class.where('created_at > ? and created_at < ?', 60.days.ago, 30.days.ago).count
  end

  def self.report_users_by_trust_level(report)
    report.data = []
    User.counts_by_trust_level.each do |level, count|
      report.data << {x: level.to_i, y: count}
    end
  end

  def self.report_favorites(report)
    basic_report_about report, Topic, :starred_counts_per_day
    query = TopicUser.where(starred: true)
    report.total = query.count
    report.prev30Days = query.where('starred_at > ? and starred_at < ?', 60.days.ago, 30.days.ago).count
  end

  # Post action counts:

  def self.report_flags(report)
    report.data = []
    (0..30).to_a.reverse.each do |i|
      count = PostAction.where('date(created_at) = ?', i.days.ago.utc.to_date)
        .where(post_action_type_id: PostActionType.flag_types.values)
        .count
      if count > 0
        report.data << {x: i.days.ago.utc.to_date.to_s, y: count}
      end
    end
    flagsQuery = PostAction.where(post_action_type_id: PostActionType.flag_types.values)
    report.total = flagsQuery.count
    report.prev30Days = flagsQuery.where('created_at > ? and created_at < ?', 60.days.ago, 30.days.ago).count
  end

  def self.report_likes(report)
    post_action_report report, PostActionType.types[:like]
  end

  def self.report_bookmarks(report)
    post_action_report report, PostActionType.types[:bookmark]
  end

  def self.post_action_report(report, post_action_type)
    report.data = []
    PostAction.count_per_day_for_type(30, post_action_type).each do |date, count|
      report.data << {x: date, y: count}
    end
    query = PostAction.unscoped.where(post_action_type_id: post_action_type)
    report.total = query.count
    report.prev30Days = query.where('created_at > ? and created_at < ?', 60.days.ago, 30.days.ago).count
  end

  # Private messages counts:

  def self.private_messages_report(report, topic_subtype)
    basic_report_about report, Post, :private_messages_count_per_day, topic_subtype
    report.total = Post.private_posts.with_topic_subtype(topic_subtype).count
    report.prev30Days = Post.private_posts.with_topic_subtype(topic_subtype).where('posts.created_at > ? and posts.created_at < ?', 60.days.ago, 30.days.ago).count
  end

  def self.report_user_to_user_private_messages(report)
    private_messages_report report, TopicSubtype.user_to_user
  end

  def self.report_system_private_messages(report)
    private_messages_report report, TopicSubtype.system_message
  end

  def self.report_moderator_warning_private_messages(report)
    private_messages_report report, TopicSubtype.moderator_warning
  end

  def self.report_notify_moderators_private_messages(report)
    private_messages_report report, TopicSubtype.notify_moderators
  end

  def self.report_notify_user_private_messages(report)
    private_messages_report report, TopicSubtype.notify_user
  end
end
