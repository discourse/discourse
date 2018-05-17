class IncomingLinksReport

  attr_accessor :type, :data, :y_titles, :start_date, :limit

  def initialize(type)
    @type = type
    @y_titles = {}
    @data = nil
  end

  def as_json(_options = nil)
    {
      type: self.type,
      title: I18n.t("reports.#{self.type}.title"),
      xaxis: I18n.t("reports.#{self.type}.xaxis"),
      ytitles: self.y_titles,
      data: self.data,
      start_date: start_date
    }
  end

  def self.find(type, _opts = {})
    report_method = :"report_#{type}"
    return nil unless respond_to?(report_method)

    # Load the report
    report = IncomingLinksReport.new(type)

    report.start_date = _opts[:start_date] || 30.days.ago
    report.limit = _opts[:limit].to_i if _opts[:limit]

    send(report_method, report)
    report
  end

  # Return top 10 users who brought traffic to the site within the last 30 days
  def self.report_top_referrers(report)
    report.y_titles[:num_clicks] = I18n.t("reports.#{report.type}.num_clicks")
    report.y_titles[:num_topics] = I18n.t("reports.#{report.type}.num_topics")

    num_clicks = link_count_per_user(start_date: report.start_date)
    num_topics = topic_count_per_user(start_date: report.start_date)
    user_id_lookup = User.where(username: num_clicks.keys).select(:id, :username).inject({}) { |sum, v| sum[v.username] = v.id; sum; }
    report.data = []
    num_clicks.each_key do |username|
      report.data << { username: username, user_id: user_id_lookup[username], num_clicks: num_clicks[username], num_topics: num_topics[username] }
    end
    report.data = report.data.sort_by { |x| x[:num_clicks] }.reverse[0, 10]
  end

  def self.per_user(start_date:)
    @per_user_query ||= public_incoming_links
      .where('incoming_links.created_at > ? AND incoming_links.user_id IS NOT NULL', start_date)
      .joins(:user)
      .group('users.username')
  end

  def self.link_count_per_user(start_date:)
    per_user(start_date: start_date).count
  end

  def self.topic_count_per_user(start_date:)
    per_user(start_date: start_date).joins(:post).count("DISTINCT posts.topic_id")
  end

  # Return top 10 domains that brought traffic to the site within the last 30 days
  def self.report_top_traffic_sources(report)
    report.y_titles[:num_clicks] = I18n.t("reports.#{report.type}.num_clicks")
    report.y_titles[:num_topics] = I18n.t("reports.#{report.type}.num_topics")
    report.y_titles[:num_users] = I18n.t("reports.#{report.type}.num_users")

    num_clicks = link_count_per_domain(start_date: report.start_date)
    num_topics = topic_count_per_domain(num_clicks.keys)
    report.data = []
    num_clicks.each_key do |domain|
      report.data << { domain: domain, num_clicks: num_clicks[domain], num_topics: num_topics[domain] }
    end
    report.data = report.data.sort_by { |x| x[:num_clicks] }.reverse[0, 10]
  end

  def self.link_count_per_domain(limit: 10, start_date:)
    public_incoming_links
      .where('incoming_links.created_at > ?', start_date)
      .joins(incoming_referer: :incoming_domain)
      .group('incoming_domains.name')
      .order('count_all DESC')
      .limit(limit)
      .count
  end

  def self.per_domain(domains)
    public_incoming_links
      .joins(incoming_referer: :incoming_domain)
      .where('incoming_links.created_at > ? AND incoming_domains.name IN (?)', 30.days.ago, domains)
      .group('incoming_domains.name')
  end

  def self.topic_count_per_domain(domains)
    # COUNT(DISTINCT) is slow
    per_domain(domains).count("DISTINCT posts.topic_id")
  end

  def self.report_top_referred_topics(report)
    report.y_titles[:num_clicks] = I18n.t("reports.#{report.type}.num_clicks")
    num_clicks = link_count_per_topic(start_date: report.start_date)
    num_clicks = num_clicks.to_a.sort_by { |x| x[1] }.last(report.limit || 10).reverse
    report.data = []
    topics = Topic.select('id, slug, title').where('id in (?)', num_clicks.map { |z| z[0] })
    num_clicks.each do |topic_id, num_clicks_element|
      topic = topics.find { |t| t.id == topic_id }
      if topic
        report.data << { topic_id: topic_id, topic_title: topic.title, topic_url: topic.relative_url, num_clicks: num_clicks_element }
      end
    end
    report.data
  end

  def self.link_count_per_topic(start_date:)
    public_incoming_links
      .where('incoming_links.created_at > ? AND topic_id IS NOT NULL', start_date)
      .group('topic_id')
      .count
  end

  def self.public_incoming_links
    IncomingLink
      .joins(post: :topic)
      .where("topics.archetype = ?", Archetype.default)
  end
end
