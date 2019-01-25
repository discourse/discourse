require_dependency 'topic_subtype'

class Report
  # Change this line each time report format change
  # and you want to ensure cache is reset
  SCHEMA_VERSION = 3

  attr_accessor :type, :data, :total, :prev30Days, :start_date,
                :end_date, :category_id, :group_id, :labels, :async,
                :prev_period, :facets, :limit, :processing, :average, :percent,
                :higher_is_better, :icon, :modes, :category_filtering,
                :group_filtering, :prev_data, :prev_start_date, :prev_end_date,
                :dates_filtering, :error, :primary_color, :secondary_color

  def self.default_days
    30
  end

  def initialize(type)
    @type = type
    @start_date ||= Report.default_days.days.ago.utc.beginning_of_day
    @end_date ||= Time.now.utc.end_of_day
    @prev_end_date = @start_date
    @average = false
    @percent = false
    @higher_is_better = true
    @category_filtering = false
    @group_filtering = false
    @modes = [:table, :chart]
    @prev_data = nil
    @dates_filtering = true

    tertiary = ColorScheme.hex_for_name('tertiary') || '0088cc'
    @primary_color = rgba_color(tertiary)
    @secondary_color = rgba_color(tertiary, 0.1)
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
      report.limit,
      SCHEMA_VERSION,
    ].compact.map(&:to_s).join(':')
  end

  def self.clear_cache(type = nil)
    pattern = type ? "reports:#{type}:*" : "reports:*"

    Discourse.cache.keys(pattern).each do |key|
      Discourse.cache.redis.del(key)
    end
  end

  def self.wrap_slow_query(timeout = 20000)
    ActiveRecord::Base.connection.transaction do
      # Set a statement timeout so we can't tie up the server
      DB.exec "SET LOCAL statement_timeout = #{timeout}"
      yield
    end
  end

  def prev_start_date
    self.start_date - (self.end_date - self.start_date)
  end

  def prev_end_date
    self.start_date
  end

  def as_json(options = nil)
    description = I18n.t("reports.#{type}.description", default: "")

    {
      type: type,
      title: I18n.t("reports.#{type}.title", default: nil),
      xaxis: I18n.t("reports.#{type}.xaxis", default: nil),
      yaxis: I18n.t("reports.#{type}.yaxis", default: nil),
      description: description.presence ? description : nil,
      data: data,
      start_date: start_date&.iso8601,
      end_date: end_date&.iso8601,
      prev_data: self.prev_data,
      prev_start_date: prev_start_date&.iso8601,
      prev_end_date: prev_end_date&.iso8601,
      category_id: category_id,
      group_id: group_id,
      prev30Days: self.prev30Days,
      dates_filtering: self.dates_filtering,
      report_key: Report.cache_key(self),
      primary_color: self.primary_color,
      secondary_color: self.secondary_color,
      labels: labels || [
        {
          type: :date,
          property: :x,
          title: I18n.t("reports.default.labels.day")
        },
        {
          type: :number,
          property: :y,
          title: I18n.t("reports.default.labels.count")
        },
      ],
      processing: self.processing,
      average: self.average,
      percent: self.percent,
      higher_is_better: self.higher_is_better,
      category_filtering: self.category_filtering,
      group_filtering: self.group_filtering,
      modes: self.modes,
    }.tap do |json|
      json[:icon] = self.icon if self.icon
      json[:error] = self.error if self.error
      json[:total] = self.total if self.total
      json[:prev_period] = self.prev_period if self.prev_period
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
    Discourse.cache.write(cache_key(report), report.as_json, force: true, expires_in: duration)
  end

  def self.find(type, opts = nil)
    begin
      report = _get(type, opts)
      report_method = :"report_#{type}"

      begin
        wrap_slow_query do
          if respond_to?(report_method)
            send(report_method, report)
          elsif type =~ /_reqs$/
            req_report(report, type.split(/_reqs$/)[0].to_sym)
          else
            return nil
          end
        end
      rescue ActiveRecord::QueryCanceled, PG::QueryCanceled => e
        report.error = :timeout
      end
    rescue Exception => e
      # ensures that if anything unexpected prevents us from
      # creating a report object we fail elegantly and log an error
      if !report
        Rails.logger.error("Couldn’t create report `#{type}`: <#{e.class} #{e.message}>")
        return nil
      end

      report.error = :exception

      # given reports can be added by plugins we don’t want dashboard failures
      # on report computation, however we do want to log which report is provoking
      # an error
      Rails.logger.error("Error while computing report `#{report.type}`: #{e.message}\n#{e.backtrace.join("\n")}")
    end

    report
  end

  def self.report_consolidated_page_views(report)
    filters = %w[
      page_view_crawler
      page_view_logged_in
      page_view_anon
    ]

    report.modes = [:stacked_chart]

    tertiary = ColorScheme.hex_for_name('tertiary') || '0088cc'
    danger = ColorScheme.hex_for_name('danger') || 'e45735'

    requests = filters.map do |filter|
      color = report.rgba_color(tertiary)

      if filter == "page_view_anon"
        color = report.rgba_color(tertiary, 0.5)
      end

      if filter == "page_view_crawler"
        color = report.rgba_color(danger, 0.75)
      end

      {
        req: filter,
        label: I18n.t("reports.consolidated_page_views.xaxis.#{filter}"),
        color: color,
        data: ApplicationRequest.where(req_type: ApplicationRequest.req_types[filter])
      }
    end

    requests.each do |request|
      request[:data] = request[:data].where('date >= ? AND date <= ?', report.start_date, report.end_date)
        .order(date: :asc)
        .group(:date)
        .sum(:count)
        .map { |date, count| { x: date, y: count } }
    end

    report.data = requests
  end

  def self.req_report(report, filter = nil)
    data =
      if filter == :page_view_total
        ApplicationRequest.where(req_type: [
          ApplicationRequest.req_types.reject { |k, v| k =~ /mobile/ }.map { |k, v| v if k =~ /page_view/ }.compact
        ].flatten)
      else
        ApplicationRequest.where(req_type: ApplicationRequest.req_types[filter])
      end

    if filter == :page_view_total
      report.icon = 'file'
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
    report.group_filtering = true
    report.icon = 'user'

    basic_report_about report, UserVisit, :by_day, report.start_date, report.end_date, report.group_id
    add_counts report, UserVisit, 'visited_at'

    report.prev30Days = UserVisit.where("visited_at >= ? and visited_at < ?", report.start_date - 30.days, report.start_date).count
  end

  def self.report_mobile_visits(report)
    basic_report_about report, UserVisit, :mobile_by_day, report.start_date, report.end_date
    report.total      = UserVisit.where(mobile: true).count
    report.prev30Days = UserVisit.where(mobile: true).where("visited_at >= ? and visited_at < ?", report.start_date - 30.days, report.start_date).count
  end

  def self.report_signups(report)
    report.group_filtering = true

    report.icon = 'user-plus'

    if report.group_id
      basic_report_about report, User.real, :count_by_signup_date, report.start_date, report.end_date, report.group_id
      add_counts report, User.real, 'users.created_at'
    else
      report_about report, User.real, :count_by_signup_date
    end

    # add_prev_data report, User.real, :count_by_signup_date, report.prev_start_date, report.prev_end_date
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
      prev_period_data = User.real.count_by_first_post(report.prev_start_date, report.prev_end_date)
      report.prev_period = prev_period_data.sum { |k, v| v }
      # report.prev_data = prev_period_data.map { |k, v| { x: k, y: v } }
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
      prev_data = UserAction.count_daily_engaged_users(report.prev_start_date, report.prev_end_date)

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
    report.labels = [
      {
        type: :date,
        property: :x,
        title: I18n.t("reports.default.labels.day")
      },
      {
        type: :percent,
        property: :y,
        title: I18n.t("reports.default.labels.percent")
      },
    ]

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
      report.prev_period = dau_avg.call(report.prev_start_date, report.prev_end_date)
    end

    if report.facets.include?(:prev30Days)
      report.prev30Days = dau_avg.call(report.start_date - 30.days, report.start_date)
    end
  end

  def self.report_profile_views(report)
    report.group_filtering = true
    start_date = report.start_date
    end_date = report.end_date
    basic_report_about report, UserProfileView, :profile_views_by_day, start_date, end_date, report.group_id

    report.total = UserProfile.sum(:views)
    report.prev30Days = UserProfileView.where("viewed_at >= ? AND viewed_at < ?", start_date - 30.days, start_date + 1).count
  end

  def self.report_topics(report)
    report.category_filtering = true
    basic_report_about report, Topic, :listable_count_per_day, report.start_date, report.end_date, report.category_id
    countable = Topic.listable_topics
    countable = countable.in_category_and_subcategories(report.category_id) if report.category_id
    add_counts report, countable, 'topics.created_at'
  end

  def self.report_posts(report)
    report.modes = [:table, :chart]
    report.category_filtering = true
    basic_report_about report, Post, :public_posts_count_per_day, report.start_date, report.end_date, report.category_id
    countable = Post.public_posts.where(post_type: Post.types[:regular])
    if report.category_id
      countable = countable.joins(:topic).merge(Topic.in_category_and_subcategories(report.category_id))
    end
    add_counts report, countable, 'posts.created_at'
  end

  def self.report_time_to_first_response(report)
    report.category_filtering = true
    report.icon = 'reply'
    report.higher_is_better = false
    report.data = []
    Topic.time_to_first_response_per_day(report.start_date, report.end_date, category_id: report.category_id).each do |r|
      report.data << { x: r["date"], y: r["hours"].to_f.round(2) }
    end
    report.total = Topic.time_to_first_response_total(category_id: report.category_id)
    report.prev30Days = Topic.time_to_first_response_total(start_date: report.start_date - 30.days, end_date: report.start_date, category_id: report.category_id)
  end

  def self.report_topics_with_no_response(report)
    report.category_filtering = true
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

  def self.add_prev_data(report, subject_class, report_method, *args)
    if report.modes.include?(:chart) && report.facets.include?(:prev_period)
      prev_data = subject_class.send(report_method, *args)
      report.prev_data = prev_data.map { |k, v| { x: k, y: v } }
    end
  end

  def self.add_counts(report, subject_class, query_column = 'created_at')
    if report.facets.include?(:prev_period)
      prev_data = subject_class
        .where("#{query_column} >= ? and #{query_column} < ?",
          report.prev_start_date,
          report.prev_end_date)

      report.prev_period = prev_data.count
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

    report.modes = [:table]

    report.dates_filtering = false

    report.labels = [
      {
        property: :key,
        title: I18n.t("reports.users_by_trust_level.labels.level")
      },
      {
        property: :y,
        type: :number,
        title: I18n.t("reports.default.labels.count")
      }
    ]

    User.real.group('trust_level').count.sort.each do |level, count|
      key = TrustLevel.levels[level.to_i]
      url = Proc.new { |k| "/admin/users/list/#{k}" }
      report.data << { url: url.call(key), key: key, x: level.to_i, y: count }
    end
  end

  # Post action counts:
  def self.report_flags(report)
    report.category_filtering = true
    report.icon = 'flag'
    report.higher_is_better = false

    basic_report_about report, PostAction, :flag_count_by_date, report.start_date, report.end_date, report.category_id
    countable = PostAction.where(post_action_type_id: PostActionType.flag_types_without_custom.values)
    countable = countable.joins(post: :topic).merge(Topic.in_category_and_subcategories(report.category_id)) if report.category_id
    add_counts report, countable, 'post_actions.created_at'
  end

  def self.report_likes(report)
    report.category_filtering = true
    report.icon = 'heart'
    post_action_report report, PostActionType.types[:like]
  end

  def self.report_bookmarks(report)
    report.category_filtering = true
    report.icon = 'bookmark'
    post_action_report report, PostActionType.types[:bookmark]
  end

  def self.post_action_report(report, post_action_type)
    report.data = []
    PostAction.count_per_day_for_type(post_action_type, category_id: report.category_id, start_date: report.start_date, end_date: report.end_date).each do |date, count|
      report.data << { x: date, y: count }
    end
    countable = PostAction.unscoped.where(post_action_type_id: post_action_type)
    countable = countable.joins(post: :topic).merge(Topic.in_category_and_subcategories(report.category_id)) if report.category_id
    add_counts report, countable, 'post_actions.created_at'
  end

  def self.private_messages_report(report, topic_subtype)
    report.icon = 'envelope'
    subject = Topic.where('topics.user_id > 0')
    basic_report_about report, subject, :private_message_topics_count_per_day, report.start_date, report.end_date, topic_subtype
    subject = Topic.private_messages.where('topics.user_id > 0').with_subtype(topic_subtype)
    add_counts report, subject, 'topics.created_at'
  end

  def self.report_user_to_user_private_messages(report)
    report.icon = 'envelope'
    private_messages_report report, TopicSubtype.user_to_user
  end

  def self.report_user_to_user_private_messages_with_replies(report)
    report.icon = 'envelope'
    topic_subtype = TopicSubtype.user_to_user
    subject = Post.where('posts.user_id > 0')
    basic_report_about report, subject, :private_messages_count_per_day, report.start_date, report.end_date, topic_subtype
    subject = Post.private_posts.where('posts.user_id > 0').with_topic_subtype(topic_subtype)
    add_counts report, subject, 'posts.created_at'
  end

  def self.report_system_private_messages(report)
    report.icon = 'envelope'
    private_messages_report report, TopicSubtype.system_message
  end

  def self.report_moderator_warning_private_messages(report)
    report.icon = 'envelope'
    private_messages_report report, TopicSubtype.moderator_warning
  end

  def self.report_notify_moderators_private_messages(report)
    report.icon = 'envelope'
    private_messages_report report, TopicSubtype.notify_moderators
  end

  def self.report_notify_user_private_messages(report)
    report.icon = 'envelope'
    private_messages_report report, TopicSubtype.notify_user
  end

  def self.report_web_crawlers(report)
    report.labels = [
      {
        type: :string,
        property: :user_agent,
        title: I18n.t("reports.web_crawlers.labels.user_agent")
      },
      {
        property: :count,
        type: :number,
        title: I18n.t("reports.web_crawlers.labels.page_views")
      }
    ]
    report.modes = [:table]
    report.data = WebCrawlerRequest.where('date >= ? and date <= ?', report.start_date, report.end_date)
      .limit(200)
      .order('sum_count DESC')
      .group(:user_agent).sum(:count)
      .map { |ua, count| { user_agent: ua, count: count } }
  end

  def self.report_users_by_type(report)
    report.data = []

    report.modes = [:table]

    report.dates_filtering = false

    report.labels = [
      {
        property: :x,
        title: I18n.t("reports.users_by_type.labels.type")
      },
      {
        property: :y,
        type: :number,
        title: I18n.t("reports.default.labels.count")
      }
    ]

    label = Proc.new { |x| I18n.t("reports.users_by_type.xaxis_labels.#{x}") }
    url = Proc.new { |key| "/admin/users/list/#{key}" }

    admins = User.real.admins.count
    report.data << { url: url.call("admins"), icon: "shield-alt", key: "admins", x: label.call("admin"), y: admins } if admins > 0

    moderators = User.real.moderators.count
    report.data << { url: url.call("moderators"), icon: "shield-alt", key: "moderators", x: label.call("moderator"), y: moderators } if moderators > 0

    suspended = User.real.suspended.count
    report.data << { url: url.call("suspended"), icon: "ban", key: "suspended", x: label.call("suspended"), y: suspended } if suspended > 0

    silenced = User.real.silenced.count
    report.data << { url: url.call("silenced"), icon: "ban", key: "silenced", x: label.call("silenced"), y: silenced } if silenced > 0
  end

  def self.report_top_referred_topics(report)
    report.category_filtering = true
    report.modes = [:table]

    report.labels = [
      {
        type: :topic,
        properties: {
          title: :topic_title,
          id: :topic_id
        },
        title: I18n.t("reports.top_referred_topics.labels.topic")
      },
      {
        property: :num_clicks,
        type: :number,
        title: I18n.t("reports.top_referred_topics.labels.num_clicks")
      }
    ]

    options = {
      end_date: report.end_date,
      start_date: report.start_date,
      limit: report.limit || 8,
      category_id: report.category_id
    }
    result = nil
    result = IncomingLinksReport.find(:top_referred_topics, options)
    report.data = result.data
  end

  def self.report_top_traffic_sources(report)
    report.category_filtering = true
    report.modes = [:table]

    report.labels = [
      {
        property: :domain,
        title: I18n.t("reports.top_traffic_sources.labels.domain")
      },
      {
        property: :num_clicks,
        type: :number,
        title: I18n.t("reports.top_traffic_sources.labels.num_clicks")
      },
      {
        property: :num_topics,
        type: :number,
        title: I18n.t("reports.top_traffic_sources.labels.num_topics")
      }
    ]

    options = {
      end_date: report.end_date,
      start_date: report.start_date,
      limit: report.limit || 8,
      category_id: report.category_id
    }

    result = IncomingLinksReport.find(:top_traffic_sources, options)
    report.data = result.data
  end

  def self.report_top_referrers(report)
    report.modes = [:table]

    report.labels = [
      {
        type: :user,
        properties: {
          username: :username,
          id: :user_id,
          avatar: :user_avatar_template,
        },
        title: I18n.t("reports.top_referrers.labels.user")
      },
      {
        property: :num_clicks,
        type: :number,
        title: I18n.t("reports.top_referrers.labels.num_clicks")
      },
      {
        property: :num_topics,
        type: :number,
        title: I18n.t("reports.top_referrers.labels.num_topics")
      }
    ]

    options = {
      end_date: report.end_date,
      start_date: report.start_date,
      limit: report.limit || 8
    }

    result = IncomingLinksReport.find(:top_referrers, options)
    report.data = result.data
  end

  def self.report_trending_search(report)
    report.labels = [
      {
        property: :term,
        type: :text,
        title: I18n.t("reports.trending_search.labels.term")
      },
      {
        property: :searches,
        type: :number,
        title: I18n.t("reports.trending_search.labels.searches")
      },
      {
        type: :percent,
        property: :ctr,
        title: I18n.t("reports.trending_search.labels.click_through")
      }
    ]

    report.data = []

    report.modes = [:table]

    trends = SearchLog.trending_from(report.start_date,
      end_date: report.end_date,
      limit: report.limit
    )

    trends.each do |trend|
      report.data << {
        term: trend.term,
        searches: trend.searches,
        ctr: trend.ctr
      }
    end
  end

  def self.report_moderators_activity(report)
    report.labels = [
      {
        type: :user,
        properties: {
          username: :username,
          id: :user_id,
          avatar: :user_avatar_template,
        },
        title: I18n.t("reports.moderators_activity.labels.moderator"),
      },
      {
        property: :flag_count,
        type: :number,
        title: I18n.t("reports.moderators_activity.labels.flag_count")
      },
      {
        type: :seconds,
        property: :time_read,
        title: I18n.t("reports.moderators_activity.labels.time_read")
      },
      {
        property: :topic_count,
        type: :number,
        title: I18n.t("reports.moderators_activity.labels.topic_count")
      },
      {
        property: :pm_count,
        type: :number,
        title: I18n.t("reports.moderators_activity.labels.pm_count")
      },
      {
        property: :post_count,
        type: :number,
        title: I18n.t("reports.moderators_activity.labels.post_count")
      },
      {
        property: :revision_count,
        type: :number,
        title: I18n.t("reports.moderators_activity.labels.revision_count")
      }
    ]

    report.modes = [:table]
    report.data = []

    query = <<~SQL
    WITH mods AS (
    SELECT
    id AS user_id,
    username_lower AS username,
    uploaded_avatar_id
    FROM users u
    WHERE u.moderator = 'true'
    AND u.id > 0
    ),
    time_read AS (
    SELECT SUM(uv.time_read) AS time_read,
    uv.user_id
    FROM mods m
    JOIN user_visits uv
    ON m.user_id = uv.user_id
    WHERE uv.visited_at >= '#{report.start_date}'
    AND uv.visited_at <= '#{report.end_date}'
    GROUP BY uv.user_id
    ),
    flag_count AS (
        WITH period_actions AS (
        SELECT agreed_by_id,
        disagreed_by_id
        FROM post_actions
        WHERE post_action_type_id IN (#{PostActionType.flag_types_without_custom.values.join(',')})
        AND created_at >= '#{report.start_date}'
        AND created_at <= '#{report.end_date}'
        ),
        agreed_flags AS (
        SELECT pa.agreed_by_id AS user_id,
        COUNT(*) AS flag_count
        FROM mods m
        JOIN period_actions pa
        ON pa.agreed_by_id = m.user_id
        GROUP BY agreed_by_id
        ),
        disagreed_flags AS (
        SELECT pa.disagreed_by_id AS user_id,
        COUNT(*) AS flag_count
        FROM mods m
        JOIN period_actions pa
        ON pa.disagreed_by_id = m.user_id
        GROUP BY disagreed_by_id
        )
    SELECT
    COALESCE(af.user_id, df.user_id) AS user_id,
    COALESCE(af.flag_count, 0) + COALESCE(df.flag_count, 0) AS flag_count
    FROM agreed_flags af
    FULL OUTER JOIN disagreed_flags df
    ON df.user_id = af.user_id
    ),
    revision_count AS (
    SELECT pr.user_id,
    COUNT(*) AS revision_count
    FROM mods m
    JOIN post_revisions pr
    ON pr.user_id = m.user_id
    JOIN posts p
    ON p.id = pr.post_id
    WHERE pr.created_at >= '#{report.start_date}'
    AND pr.created_at <= '#{report.end_date}'
    AND p.user_id <> pr.user_id
    GROUP BY pr.user_id
    ),
    topic_count AS (
    SELECT t.user_id,
    COUNT(*) AS topic_count
    FROM mods m
    JOIN topics t
    ON t.user_id = m.user_id
    WHERE t.archetype = 'regular'
    AND t.created_at >= '#{report.start_date}'
    AND t.created_at <= '#{report.end_date}'
    GROUP BY t.user_id
    ),
    post_count AS (
    SELECT p.user_id,
    COUNT(*) AS post_count
    FROM mods m
    JOIN posts p
    ON p.user_id = m.user_id
    JOIN topics t
    ON t.id = p.topic_id
    WHERE t.archetype = 'regular'
    AND p.created_at >= '#{report.start_date}'
    AND p.created_at <= '#{report.end_date}'
    GROUP BY p.user_id
    ),
    pm_count AS (
    SELECT p.user_id,
    COUNT(*) AS pm_count
    FROM mods m
    JOIN posts p
    ON p.user_id = m.user_id
    JOIN topics t
    ON t.id = p.topic_id
    WHERE t.archetype = 'private_message'
    AND p.created_at >= '#{report.start_date}'
    AND p.created_at <= '#{report.end_date}'
    GROUP BY p.user_id
    )

    SELECT
    m.user_id,
    m.username,
    m.uploaded_avatar_id,
    tr.time_read,
    fc.flag_count,
    rc.revision_count,
    tc.topic_count,
    pc.post_count,
    pmc.pm_count
    FROM mods m
    LEFT JOIN time_read tr ON tr.user_id = m.user_id
    LEFT JOIN flag_count fc ON fc.user_id = m.user_id
    LEFT JOIN revision_count rc ON rc.user_id = m.user_id
    LEFT JOIN topic_count tc ON tc.user_id = m.user_id
    LEFT JOIN post_count pc ON pc.user_id = m.user_id
    LEFT JOIN pm_count pmc ON pmc.user_id = m.user_id
    ORDER BY m.username
    SQL

    DB.query(query).each do |row|
      mod = {}
      mod[:username] = row.username
      mod[:user_id] = row.user_id
      mod[:user_avatar_template] = User.avatar_template(row.username, row.uploaded_avatar_id)
      mod[:time_read] = row.time_read
      mod[:flag_count] = row.flag_count
      mod[:revision_count] = row.revision_count
      mod[:topic_count] = row.topic_count
      mod[:post_count] = row.post_count
      mod[:pm_count] = row.pm_count
      report.data << mod
    end
  end

  def self.report_flags_status(report)
    report.modes = [:table]

    report.labels = [
      {
        type: :post,
        properties: {
          topic_id: :topic_id,
          number: :post_number,
          truncated_raw: :post_type
        },
        title: I18n.t("reports.flags_status.labels.flag")
      },
      {
        type: :user,
        properties: {
          username: :staff_username,
          id: :staff_id,
          avatar: :staff_avatar_template
        },
        title: I18n.t("reports.flags_status.labels.assigned")
      },
      {
        type: :user,
        properties: {
          username: :poster_username,
          id: :poster_id,
          avatar: :poster_avatar_template
        },
        title: I18n.t("reports.flags_status.labels.poster")
      },
      {
        type: :user,
        properties: {
          username: :flagger_username,
          id: :flagger_id,
          avatar: :flagger_avatar_template
          },
        title: I18n.t("reports.flags_status.labels.flagger")
      },
      {
        type: :seconds,
        property: :response_time,
        title: I18n.t("reports.flags_status.labels.time_to_resolution")
      }
    ]

    report.data = []

    flag_types = PostActionType.flag_types

    sql = <<~SQL
    WITH period_actions AS (
    SELECT id,
    post_action_type_id,
    created_at,
    agreed_at,
    disagreed_at,
    deferred_at,
    agreed_by_id,
    disagreed_by_id,
    deferred_by_id,
    post_id,
    user_id,
    COALESCE(disagreed_at, agreed_at, deferred_at) AS responded_at
    FROM post_actions
    WHERE post_action_type_id IN (#{flag_types.values.join(',')})
      AND created_at >= '#{report.start_date}'
      AND created_at <= '#{report.end_date}'
    ORDER BY created_at DESC
    ),
    poster_data AS (
    SELECT pa.id,
    p.user_id AS poster_id,
    p.topic_id as topic_id,
    p.post_number as post_number,
    u.username_lower AS poster_username,
    u.uploaded_avatar_id AS poster_avatar_id
    FROM period_actions pa
    JOIN posts p
    ON p.id = pa.post_id
    JOIN users u
    ON u.id = p.user_id
    ),
    flagger_data AS (
    SELECT pa.id,
    u.id AS flagger_id,
    u.username_lower AS flagger_username,
    u.uploaded_avatar_id AS flagger_avatar_id
    FROM period_actions pa
    JOIN users u
    ON u.id = pa.user_id
    ),
    staff_data AS (
    SELECT pa.id,
    u.id AS staff_id,
    u.username_lower AS staff_username,
    u.uploaded_avatar_id AS staff_avatar_id
    FROM period_actions pa
    JOIN users u
    ON u.id = COALESCE(pa.agreed_by_id, pa.disagreed_by_id, pa.deferred_by_id)
    )
    SELECT
    sd.staff_username,
    sd.staff_id,
    sd.staff_avatar_id,
    pd.poster_username,
    pd.poster_id,
    pd.poster_avatar_id,
    pd.post_number,
    pd.topic_id,
    fd.flagger_username,
    fd.flagger_id,
    fd.flagger_avatar_id,
    pa.post_action_type_id,
    pa.created_at,
    pa.agreed_at,
    pa.disagreed_at,
    pa.deferred_at,
    pa.agreed_by_id,
    pa.disagreed_by_id,
    pa.deferred_by_id,
    COALESCE(pa.disagreed_at, pa.agreed_at, pa.deferred_at) AS responded_at
    FROM period_actions pa
    FULL OUTER JOIN staff_data sd
    ON sd.id = pa.id
    FULL OUTER JOIN flagger_data fd
    ON fd.id = pa.id
    FULL OUTER JOIN poster_data pd
    ON pd.id = pa.id
    SQL

    DB.query(sql).each do |row|
      data = {}

      data[:post_type] = flag_types.key(row.post_action_type_id).to_s
      data[:post_number] = row.post_number
      data[:topic_id] = row.topic_id

      if row.staff_id
        data[:staff_username] = row.staff_username
        data[:staff_id] = row.staff_id
        data[:staff_avatar_template] = User.avatar_template(row.staff_username, row.staff_avatar_id)
      end

      if row.poster_id
        data[:poster_username] = row.poster_username
        data[:poster_id] = row.poster_id
        data[:poster_avatar_template] = User.avatar_template(row.poster_username, row.poster_avatar_id)
      end

      if row.flagger_id
        data[:flagger_id] = row.flagger_id
        data[:flagger_username] = row.flagger_username
        data[:flagger_avatar_template] = User.avatar_template(row.flagger_username, row.flagger_avatar_id)
      end

      if row.agreed_by_id
        data[:resolution] = I18n.t("reports.flags_status.values.agreed")
      elsif row.disagreed_by_id
        data[:resolution] = I18n.t("reports.flags_status.values.disagreed")
      elsif row.deferred_by_id
        data[:resolution] = I18n.t("reports.flags_status.values.deferred")
      else
        data[:resolution] = I18n.t("reports.flags_status.values.no_action")
      end
      data[:response_time] = row.responded_at ? row.responded_at - row.created_at : nil
      report.data << data
    end
  end

  def self.report_post_edits(report)
    report.category_filtering = true
    report.modes = [:table]

    report.labels = [
      {
        type: :post,
        properties: {
          topic_id: :topic_id,
          number: :post_number,
          truncated_raw: :post_raw
        },
        title: I18n.t("reports.post_edits.labels.post")
      },
      {
        type: :user,
        properties: {
          username: :editor_username,
          id: :editor_id,
          avatar: :editor_avatar_template,
        },
        title: I18n.t("reports.post_edits.labels.editor")
      },
      {
        type: :user,
        properties: {
          username: :author_username,
          id: :author_id,
          avatar: :author_avatar_template,
        },
        title: I18n.t("reports.post_edits.labels.author")
      },
      {
        type: :text,
        property: :edit_reason,
        title: I18n.t("reports.post_edits.labels.edit_reason")
      },
    ]

    report.data = []

    sql = <<~SQL
    WITH period_revisions AS (
    SELECT pr.user_id AS editor_id,
    pr.number AS revision_version,
    pr.created_at,
    pr.post_id,
    u.username AS editor_username,
    u.uploaded_avatar_id as editor_avatar_id
    FROM post_revisions pr
    JOIN users u
    ON u.id = pr.user_id
    WHERE u.id > 0
    AND pr.created_at >= '#{report.start_date}'
    AND pr.created_at <= '#{report.end_date}'
    ORDER BY pr.created_at DESC
    LIMIT 20
    )
    SELECT pr.editor_id,
    pr.editor_username,
    pr.editor_avatar_id,
    p.user_id AS author_id,
    u.username AS author_username,
    u.uploaded_avatar_id AS author_avatar_id,
    pr.revision_version,
    p.version AS post_version,
    pr.post_id,
    left(p.raw, 40) AS post_raw,
    p.topic_id,
    p.post_number,
    p.edit_reason,
    pr.created_at
    FROM period_revisions pr
    JOIN posts p
    ON p.id = pr.post_id
    JOIN users u
    ON u.id = p.user_id
    SQL

    if report.category_id
      sql += <<~SQL
      JOIN topics t
      ON t.id = p.topic_id
      WHERE t.category_id = ? OR t.category_id IN (SELECT id FROM categories WHERE categories.parent_category_id = ?)
      SQL
    end
    result = report.category_id ? DB.query(sql, report.category_id, report.category_id) : DB.query(sql)

    result.each do |r|
      revision = {}
      revision[:editor_id] = r.editor_id
      revision[:editor_username] = r.editor_username
      revision[:editor_avatar_template] = User.avatar_template(r.editor_username, r.editor_avatar_id)
      revision[:author_id] = r.author_id
      revision[:author_username] = r.author_username
      revision[:author_avatar_template] = User.avatar_template(r.author_username, r.author_avatar_id)
      revision[:edit_reason] = r.revision_version == r.post_version ? r.edit_reason : nil
      revision[:created_at] = r.created_at
      revision[:post_raw] = r.post_raw
      revision[:topic_id] = r.topic_id
      revision[:post_number] = r.post_number

      report.data << revision
    end
  end

  def self.report_user_flagging_ratio(report)
    report.data = []

    report.modes = [:table]

    report.dates_filtering = false

    report.labels = [
      {
        type: :user,
        properties: {
          username: :username,
          id: :user_id,
          avatar: :avatar_template,
        },
        title: I18n.t("reports.user_flagging_ratio.labels.user")
      },
      {
        type: :number,
        property: :disagreed_flags,
        title: I18n.t("reports.user_flagging_ratio.labels.disagreed_flags")
      },
      {
        type: :number,
        property: :agreed_flags,
        title: I18n.t("reports.user_flagging_ratio.labels.agreed_flags")
      },
      {
        type: :number,
        property: :ignored_flags,
        title: I18n.t("reports.user_flagging_ratio.labels.ignored_flags")
      },
      {
        type: :number,
        property: :score,
        title: I18n.t("reports.user_flagging_ratio.labels.score")
      },
    ]

    sql = <<~SQL
      SELECT u.id,
             u.username,
             u.uploaded_avatar_id as avatar_id,
             CASE WHEN u.silenced_till IS NOT NULL THEN 't' ELSE 'f' END as silenced,
             us.flags_disagreed AS disagreed_flags,
             us.flags_agreed AS agreed_flags,
             us.flags_ignored AS ignored_flags,
             ROUND((1-(us.flags_agreed::numeric / us.flags_disagreed::numeric)) *
                   (us.flags_disagreed - us.flags_agreed)) AS score
      FROM users AS u
        INNER JOIN user_stats AS us ON us.user_id = u.id
      WHERE u.id <> -1
        AND flags_disagreed > flags_agreed
      ORDER BY score DESC
      LIMIT 100
      SQL

    DB.query(sql).each do |row|
      flagger = {}
      flagger[:user_id] = row.id
      flagger[:username] = row.username
      flagger[:avatar_template] = User.avatar_template(row.username, row.avatar_id)
      flagger[:disagreed_flags] = row.disagreed_flags
      flagger[:ignored_flags] = row.ignored_flags
      flagger[:agreed_flags] = row.agreed_flags
      flagger[:score] = row.score

      report.data << flagger
    end
  end

  def self.report_staff_logins(report)
    report.modes = [:table]

    report.data = []

    report.labels = [
      {
        type: :user,
        properties: {
          username: :username,
          id: :user_id,
          avatar: :avatar_template,
        },
        title: I18n.t("reports.staff_logins.labels.user")
      },
      {
        property: :location,
        title: I18n.t("reports.staff_logins.labels.location")
      },
      {
        property: :created_at,
        type: :precise_date,
        title: I18n.t("reports.staff_logins.labels.login_at")
      }
    ]

    sql = <<~SQL
      SELECT
        t1.created_at created_at,
        t1.client_ip client_ip,
        u.username username,
        u.uploaded_avatar_id uploaded_avatar_id,
        u.id user_id
      FROM (
        SELECT DISTINCT ON (t.client_ip, t.user_id) t.client_ip, t.user_id, t.created_at
        FROM user_auth_token_logs t
        WHERE t.user_id IN (#{User.admins.pluck(:id).join(',')})
          AND t.created_at >= :start_date
          AND t.created_at <= :end_date
        ORDER BY t.client_ip, t.user_id, t.created_at DESC
        LIMIT #{report.limit || 20}
      ) t1
      JOIN users u ON u.id = t1.user_id
      ORDER BY created_at DESC
    SQL

    DB.query(sql, start_date: report.start_date, end_date: report.end_date).each do |row|
      data = {}
      data[:avatar_template] = User.avatar_template(row.username, row.uploaded_avatar_id)
      data[:user_id] = row.user_id
      data[:username] = row.username
      data[:location] = DiscourseIpInfo.get(row.client_ip)[:location]
      data[:created_at] = row.created_at

      report.data << data
    end
  end

  def self.report_suspicious_logins(report)
    report.modes = [:table]

    report.labels = [
      {
        type: :user,
        properties: {
          username: :username,
          id: :user_id,
          avatar: :avatar_template,
        },
        title: I18n.t("reports.suspicious_logins.labels.user")
      },
      {
        property: :client_ip,
        title: I18n.t("reports.suspicious_logins.labels.client_ip")
      },
      {
        property: :location,
        title: I18n.t("reports.suspicious_logins.labels.location")
      },
      {
        property: :browser,
        title: I18n.t("reports.suspicious_logins.labels.browser")
      },
      {
        property: :device,
        title: I18n.t("reports.suspicious_logins.labels.device")
      },
      {
        property: :os,
        title: I18n.t("reports.suspicious_logins.labels.os")
      },
      {
        type: :date,
        property: :login_time,
        title: I18n.t("reports.suspicious_logins.labels.login_time")
      },
    ]

    report.data = []

    sql = <<~SQL
      SELECT u.id user_id, u.username, u.uploaded_avatar_id, t.client_ip, t.user_agent, t.created_at login_time
      FROM user_auth_token_logs t
      JOIN users u ON u.id = t.user_id
      WHERE t.action = 'suspicious'
        AND t.created_at >= :start_date
        AND t.created_at <= :end_date
    SQL

    DB.query(sql, start_date: report.start_date, end_date: report.end_date).each do |row|
      data = {}

      ipinfo = DiscourseIpInfo.get(row.client_ip)
      browser = BrowserDetection.browser(row.user_agent)
      device = BrowserDetection.device(row.user_agent)
      os = BrowserDetection.os(row.user_agent)

      data[:username] = row.username
      data[:user_id] = row.user_id
      data[:avatar_template] = User.avatar_template(row.username, row.uploaded_avatar_id)
      data[:client_ip] = row.client_ip.to_s
      data[:location] = ipinfo[:location]
      data[:browser] = I18n.t("user_auth_tokens.browser.#{browser}")
      data[:device] = I18n.t("user_auth_tokens.device.#{device}")
      data[:os] = I18n.t("user_auth_tokens.os.#{os}")
      data[:login_time] = row.login_time

      report.data << data
    end
  end

  def self.report_storage_stats(report)
    backup_stats = begin
      BackupRestore::BackupStore.create.stats
    rescue BackupRestore::BackupStore::StorageError
      nil
    end

    report.data = {
      backups: backup_stats,
      uploads: {
        used_bytes: DiskSpace.uploads_used_bytes,
        free_bytes: DiskSpace.uploads_free_bytes
      }
    }
  end

  def self.report_top_uploads(report)
    report.modes = [:table]

    report.labels = [
      {
        type: :link,
        properties: [
          :file_url,
          :file_name,
        ],
        title: I18n.t("reports.top_uploads.labels.filename")
      },
      {
        type: :user,
        properties: {
          username: :author_username,
          id: :author_id,
          avatar: :author_avatar_template,
        },
        title: I18n.t("reports.top_uploads.labels.author")
      },
      {
        type: :text,
        property: :extension,
        title: I18n.t("reports.top_uploads.labels.extension")
      },
      {
        type: :bytes,
        property: :filesize,
        title: I18n.t("reports.top_uploads.labels.filesize")
      },
    ]

    report.data = []

    sql = <<~SQL
    SELECT
    u.id as user_id,
    u.username,
    u.uploaded_avatar_id,
    up.filesize,
    up.original_filename,
    up.extension,
    up.url
    FROM uploads up
    JOIN users u
    ON u.id = up.user_id
    WHERE up.created_at >= '#{report.start_date}' AND up.created_at <= '#{report.end_date}'
    ORDER BY up.filesize DESC
    LIMIT #{report.limit || 250}
    SQL

    DB.query(sql).each do |row|
      data = {}
      data[:author_id] = row.user_id
      data[:author_username] = row.username
      data[:author_avatar_template] = User.avatar_template(row.username, row.uploaded_avatar_id)
      data[:filesize] = row.filesize
      data[:extension] = row.extension
      data[:file_url] = Discourse.store.cdn_url(row.url)
      data[:file_name] = row.original_filename.truncate(25)

      report.data << data
    end
  end

  DiscourseEvent.on(:site_setting_saved) do |site_setting|
    if ["backup_location", "s3_backup_bucket"].include?(site_setting.name.to_s)
      clear_cache(:storage_stats)
    end
  end

  def rgba_color(hex, opacity = 1)
    if hex.size == 3
      chars = hex.scan(/\w/)
      hex = chars.zip(chars).flatten.join
    end

    if hex.size < 3
      hex = hex.ljust(6, hex.last)
    end

    rgbs = hex_to_rgbs(hex)

    "rgba(#{rgbs.join(',')},#{opacity})"
  end

  private

  def hex_to_rgbs(hex_color)
    hex_color = hex_color.gsub('#', '')
    rgbs = hex_color.scan(/../)
    rgbs
      .map! { |color| color.hex }
      .map! { |rgb| rgb.to_i }
  end
end
