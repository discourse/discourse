require_dependency 'topic_subtype'

class Report

  attr_accessor :type, :data, :total, :prev30Days, :start_date,
                :end_date, :category_id, :group_id, :labels, :async,
                :prev_period, :facets, :limit, :processing, :average, :percent,
                :higher_is_better

  def self.default_days
    30
  end

  def initialize(type)
    @type = type
    @start_date ||= Report.default_days.days.ago.beginning_of_day
    @end_date ||= Time.zone.now.end_of_day
    @average = false
    @percent = false
    @higher_is_better = true
  end

  def self.cache_key(report)
    (+"reports:") <<
    [
      report.type,
      report.category_id,
      report.start_date.to_date.strftime("%Y%m%d"),
      report.end_date.to_date.strftime("%Y%m%d"),
      report.group_id,
      report.facets,
      report.limit
    ].map(&:to_s).join(':')
  end

  def self.clear_cache
    Discourse.cache.keys("reports:*").each do |key|
      Discourse.cache.redis.del(key)
    end
  end

  def as_json(options = nil)
    description = I18n.t("reports.#{type}.description", default: "")

    {
     type: type,
     title: I18n.t("reports.#{type}.title"),
     xaxis: I18n.t("reports.#{type}.xaxis"),
     yaxis: I18n.t("reports.#{type}.yaxis"),
     description: description.presence ? description : nil,
     data: data,
     start_date: start_date&.iso8601,
     end_date: end_date&.iso8601,
     category_id: category_id,
     group_id: group_id,
     prev30Days: self.prev30Days,
     report_key: Report.cache_key(self),
     labels: labels,
     processing: self.processing,
     average: self.average,
     percent: self.percent,
     higher_is_better: self.higher_is_better
    }.tap do |json|
      json[:total] = total if total
      json[:prev_period] = prev_period if prev_period
      json[:prev30Days] = self.prev30Days if self.prev30Days
      json[:limit] = self.limit if self.limit

      if type == 'page_view_crawler_reqs'
        json[:related_report] = Report.find('web_crawlers', start_date: start_date, end_date: end_date)&.as_json
      end
    end
  end

  def Report.add_report(name, &block)
    singleton_class.instance_eval { define_method("report_#{name}", &block) }
  end

  def self._get(type, opts = nil)
    opts ||= {}

    # Load the report
    report = Report.new(type)
    report.start_date = opts[:start_date] if opts[:start_date]
    report.end_date = opts[:end_date] if opts[:end_date]
    report.category_id = opts[:category_id] if opts[:category_id]
    report.group_id = opts[:group_id] if opts[:group_id]
    report.facets = opts[:facets] || [:total, :prev30Days]
    report.limit = opts[:limit] if opts[:limit]
    report.processing = false
    report.average = opts[:average] if opts[:average]
    report.percent = opts[:percent] if opts[:percent]
    report.higher_is_better = opts[:higher_is_better] if opts[:higher_is_better]

    report
  end

  def self.find_cached(type, opts = nil)
    report = _get(type, opts)
    Discourse.cache.read(cache_key(report))
  end

  def self.cache(report, duration)
    Discourse.cache.write(Report.cache_key(report), report.as_json, force: true, expires_in: duration)
  end

  def self.find(type, opts = nil)
    report = _get(type, opts)
    report_method = :"report_#{type}"

    if respond_to?(report_method)
      send(report_method, report)
    elsif type =~ /_reqs$/
      req_report(report, type.split(/_reqs$/)[0].to_sym)
    else
      return nil
    end

    report
  end

  def self.req_report(report, filter = nil)
    data =
      if filter == :page_view_total
        ApplicationRequest.where(req_type: [
          ApplicationRequest.req_types.reject { |k, v| k =~ /mobile/ }.map { |k, v| v if k =~ /page_view/ }.compact
        ].flatten)
      else
        ApplicationRequest.where(req_type:  ApplicationRequest.req_types[filter])
      end

    report.data = []
    data.where('date >= ? AND date <= ?', report.start_date, report.end_date)
      .order(date: :asc)
      .group(:date)
      .sum(:count)
      .each do |date, count|
      report.data << { x: date, y: count }
    end

    report.total = data.sum(:count)

    report.prev30Days = data.where(
        'date >= ? AND date < ?',
        (report.start_date - 31.days), report.start_date
      ).sum(:count)
  end

  def self.report_visits(report)
    basic_report_about report, UserVisit, :by_day, report.start_date, report.end_date, report.group_id

    add_counts report, UserVisit, 'visited_at'
  end

  def self.report_mobile_visits(report)
    basic_report_about report, UserVisit, :mobile_by_day, report.start_date, report.end_date
    report.total      = UserVisit.where(mobile: true).count
    report.prev30Days = UserVisit.where(mobile: true).where("visited_at >= ? and visited_at < ?", report.start_date - 30.days, report.start_date).count
  end

  def self.report_signups(report)
    if report.group_id
      basic_report_about report, User.real, :count_by_signup_date, report.start_date, report.end_date, report.group_id
      add_counts report, User.real, 'users.created_at'
    else

      report_about report, User.real, :count_by_signup_date
    end
  end

  def self.report_new_contributors(report)
    report.data = []

    data = User.real.count_by_first_post(report.start_date, report.end_date)

    if report.facets.include?(:prev30Days)
      prev30DaysData = User.real.count_by_first_post(report.start_date - 30.days, report.start_date)
      report.prev30Days = prev30DaysData.sum { |k, v| v }
    end

    if report.facets.include?(:total)
      report.total = User.real.count_by_first_post
    end

    if report.facets.include?(:prev_period)
      prev_period_data = User.real.count_by_first_post(report.start_date - (report.end_date - report.start_date), report.start_date)
      report.prev_period = prev_period_data.sum { |k, v| v }
    end

    data.each do |key, value|
      report.data << { x: key, y: value }
    end
  end

  def self.report_daily_engaged_users(report)
    report.average = true

    report.data = []

    data = UserAction.count_daily_engaged_users(report.start_date, report.end_date)

    if report.facets.include?(:prev30Days)
      prev30DaysData = UserAction.count_daily_engaged_users(report.start_date - 30.days, report.start_date)
      report.prev30Days = prev30DaysData.sum { |k, v| v }
    end

    if report.facets.include?(:total)
      report.total = UserAction.count_daily_engaged_users
    end

    if report.facets.include?(:prev_period)
      prev_data = UserAction.count_daily_engaged_users(report.start_date - (report.end_date - report.start_date), report.start_date)

      prev = prev_data.sum { |k, v| v }
      if prev > 0
        prev = prev / ((report.end_date - report.start_date) / 1.day)
      end
      report.prev_period = prev
    end

    data.each do |key, value|
      report.data << { x: key, y: value }
    end
  end

  def self.report_dau_by_mau(report)
    report.average = true
    report.percent = true

    data_points = UserVisit.count_by_active_users(report.start_date, report.end_date)

    report.data = []

    compute_dau_by_mau = Proc.new { |data_point|
      if data_point["mau"] == 0
        0
      else
        ((data_point["dau"].to_f / data_point["mau"].to_f) * 100).ceil(2)
      end
    }

    dau_avg = Proc.new { |start_date, end_date|
      data_points = UserVisit.count_by_active_users(start_date, end_date)
      if !data_points.empty?
        sum = data_points.sum { |data_point| compute_dau_by_mau.call(data_point) }
        (sum.to_f / data_points.count.to_f).ceil(2)
      end
    }

    data_points.each do |data_point|
      report.data << { x: data_point["date"], y: compute_dau_by_mau.call(data_point) }
    end

    if report.facets.include?(:prev_period)
      report.prev_period = dau_avg.call(report.start_date - (report.end_date - report.start_date), report.start_date)
    end

    if report.facets.include?(:prev30Days)
      report.prev30Days = dau_avg.call(report.start_date - 30.days, report.start_date)
    end
  end

  def self.report_profile_views(report)
    start_date = report.start_date
    end_date = report.end_date
    basic_report_about report, UserProfileView, :profile_views_by_day, start_date, end_date, report.group_id

    report.total = UserProfile.sum(:views)
    report.prev30Days = UserProfileView.where("viewed_at >= ? AND viewed_at < ?", start_date - 30.days, start_date + 1).count
  end

  def self.report_topics(report)
    basic_report_about report, Topic, :listable_count_per_day, report.start_date, report.end_date, report.category_id
    countable = Topic.listable_topics
    countable = countable.where(category_id: report.category_id) if report.category_id
    add_counts report, countable, 'topics.created_at'
  end

  def self.report_posts(report)
    basic_report_about report, Post, :public_posts_count_per_day, report.start_date, report.end_date, report.category_id
    countable = Post.public_posts.where(post_type: Post.types[:regular])
    countable = countable.joins(:topic).where("topics.category_id = ?", report.category_id) if report.category_id
    add_counts report, countable, 'posts.created_at'
  end

  def self.report_time_to_first_response(report)
    report.higher_is_better = false
    report.data = []
    Topic.time_to_first_response_per_day(report.start_date, report.end_date, category_id: report.category_id).each do |r|
      report.data << { x: r["date"], y: r["hours"].to_f.round(2) }
    end
    report.total = Topic.time_to_first_response_total(category_id: report.category_id)
    report.prev30Days = Topic.time_to_first_response_total(start_date: report.start_date - 30.days, end_date: report.start_date, category_id: report.category_id)
  end

  def self.report_topics_with_no_response(report)
    report.data = []
    Topic.with_no_response_per_day(report.start_date, report.end_date, report.category_id).each do |r|
      report.data << { x: r["date"], y: r["count"].to_i }
    end
    report.total = Topic.with_no_response_total(category_id: report.category_id)
    report.prev30Days = Topic.with_no_response_total(start_date: report.start_date - 30.days, end_date: report.start_date, category_id: report.category_id)
  end

  def self.report_emails(report)
    report_about report, EmailLog
  end

  def self.report_about(report, subject_class, report_method = :count_per_day)
    basic_report_about report, subject_class, report_method, report.start_date, report.end_date
    add_counts report, subject_class
  end

  def self.basic_report_about(report, subject_class, report_method, *args)
    report.data = []

    subject_class.send(report_method, *args).each do |date, count|
      report.data << { x: date, y: count }
    end
  end

  def self.add_counts(report, subject_class, query_column = 'created_at')
    if report.facets.include?(:prev_period)
      report.prev_period = subject_class
        .where("#{query_column} >= ? and #{query_column} < ?",
          (report.start_date - (report.end_date - report.start_date)),
          report.start_date).count
    end

    if report.facets.include?(:total)
      report.total      = subject_class.count
    end

    if report.facets.include?(:prev30Days)
      report.prev30Days = subject_class
        .where("#{query_column} >= ? and #{query_column} < ?",
          report.start_date - 30.days,
          report.start_date).count
    end
  end

  def self.report_users_by_trust_level(report)
    report.data = []

    User.real.group('trust_level').count.sort.each do |level, count|
      key = TrustLevel.levels[level.to_i]
      url = Proc.new { |k| "/admin/users/list/#{k}" }
      report.data << { url: url.call(key), key: key, x: level.to_i, y: count }
    end
  end

  # Post action counts:
  def self.report_flags(report)
    report.higher_is_better = false

    basic_report_about report, PostAction, :flag_count_by_date, report.start_date, report.end_date, report.category_id
    countable = PostAction.where(post_action_type_id: PostActionType.flag_types_without_custom.values)
    countable = countable.joins(post: :topic).where("topics.category_id = ?", report.category_id) if report.category_id
    add_counts report, countable, 'post_actions.created_at'
  end

  def self.report_likes(report)
    post_action_report report, PostActionType.types[:like]
  end

  def self.report_bookmarks(report)
    post_action_report report, PostActionType.types[:bookmark]
  end

  def self.post_action_report(report, post_action_type)
    report.data = []
    PostAction.count_per_day_for_type(post_action_type, category_id: report.category_id, start_date: report.start_date, end_date: report.end_date).each do |date, count|
      report.data << { x: date, y: count }
    end
    countable = PostAction.unscoped.where(post_action_type_id: post_action_type)
    countable = countable.joins(post: :topic).where("topics.category_id = ?", report.category_id) if report.category_id
    add_counts report, countable, 'post_actions.created_at'
  end

  # Private messages counts:

  def self.private_messages_report(report, topic_subtype)
    basic_report_about report, Topic, :private_message_topics_count_per_day, report.start_date, report.end_date, topic_subtype
    add_counts report, Topic.private_messages.with_subtype(topic_subtype), 'topics.created_at'
  end

  def self.report_user_to_user_private_messages(report)
    private_messages_report report, TopicSubtype.user_to_user
  end

  def self.report_user_to_user_private_messages_with_replies(report)
    topic_subtype = TopicSubtype.user_to_user
    basic_report_about report, Post, :private_messages_count_per_day, report.start_date, report.end_date, topic_subtype
    add_counts report, Post.private_posts.with_topic_subtype(topic_subtype), 'posts.created_at'
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

  def self.report_web_crawlers(report)
    report.data = WebCrawlerRequest.where('date >= ? and date <= ?', report.start_date, report.end_date)
      .limit(200)
      .order('sum_count DESC')
      .group(:user_agent).sum(:count)
      .map { |ua, count| { x: ua, y: count } }
  end

  def self.report_users_by_type(report)
    report.data = []

    label = Proc.new { |x| I18n.t("reports.users_by_type.xaxis_labels.#{x}") }
    url = Proc.new { |key| "/admin/users/list/#{key}" }

    admins = User.real.admins.count
    report.data << { url: url.call("admins"), icon: "shield", key: "admins", x: label.call("admin"), y: admins } if admins > 0

    moderators = User.real.moderators.count
    report.data << { url: url.call("moderators"), icon: "shield", key: "moderators", x: label.call("moderator"), y: moderators } if moderators > 0

    suspended = User.real.suspended.count
    report.data << { url: url.call("suspended"), icon: "ban", key: "suspended", x: label.call("suspended"), y: suspended } if suspended > 0

    silenced = User.real.silenced.count
    report.data << { url: url.call("silenced"), icon: "ban", key: "silenced", x: label.call("silenced"), y: silenced } if silenced > 0
  end

  def self.report_top_referred_topics(report)
    report.labels = [I18n.t("reports.top_referred_topics.xaxis"),
      I18n.t("reports.top_referred_topics.num_clicks")]
    result = IncomingLinksReport.find(:top_referred_topics, start_date: 7.days.ago, limit: report.limit)
    report.data = result.data
  end

  def self.report_trending_search(report)
    report.data = []

    select_sql = <<~SQL
      lower(term) term,
      COUNT(*) AS searches,
      SUM(CASE
               WHEN search_result_id IS NOT NULL THEN 1
               ELSE 0
           END) AS click_through,
      COUNT(DISTINCT ip_address) AS unique_searches
    SQL

    trends = SearchLog.select(select_sql)
      .where('created_at > ?  AND created_at <= ?', report.start_date, report.end_date)
      .group('lower(term)')
      .order('unique_searches DESC, click_through ASC, term ASC')
      .limit(report.limit || 20).to_a

    report.labels = [:term, :searches, :click_through].map { |key|
      I18n.t("reports.trending_search.labels.#{key}")
    }

    trends.each do |trend|
      ctr =
        if trend.click_through == 0 || trend.searches == 0
          0
        else
          trend.click_through.to_f / trend.searches.to_f
        end

      report.data << {
        term: trend.term,
        unique_searches: trend.unique_searches,
        ctr: (ctr * 100).ceil(1).to_s + "%"
      }
    end
  end
end
