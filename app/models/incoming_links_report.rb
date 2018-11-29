class IncomingLinksReport

  attr_accessor :type, :data, :y_titles, :start_date, :end_date, :limit, :category_id

  def initialize(type)
    @type = type
    @y_titles = {}
    @data = nil
    @category_id = nil
  end

  def as_json(_options = nil)
    {
      type: self.type,
      title: I18n.t("reports.#{self.type}.title"),
      xaxis: I18n.t("reports.#{self.type}.xaxis"),
      ytitles: self.y_titles,
      data: self.data,
      start_date: start_date,
      end_date: end_date
    }
  end

  def self.find(type, _opts = {})
    report_method = :"report_#{type}"
    return nil unless respond_to?(report_method)

    # Load the report
    report = IncomingLinksReport.new(type)

    report.start_date = _opts[:start_date] || 30.days.ago
    report.end_date = _opts[:end_date] || Time.now.end_of_day
    report.limit = _opts[:limit].to_i if _opts[:limit]
    report.category_id = _opts[:category_id] if _opts[:category_id]

    send(report_method, report)
    report
  end

  # Return top 10 users who brought traffic to the site within the last 30 days
  def self.report_top_referrers(report)
    report.y_titles[:num_clicks] = I18n.t("reports.#{report.type}.num_clicks")
    report.y_titles[:num_topics] = I18n.t("reports.#{report.type}.num_topics")

    num_clicks = link_count_per_user(start_date: report.start_date, end_date: report.end_date, category_id: report.category_id)
    num_topics = topic_count_per_user(start_date: report.start_date, end_date: report.end_date, category_id: report.category_id)
    user_id_lookup = User
      .where(username: num_clicks.keys)
      .select(:id, :username, :uploaded_avatar_id)
      .inject({}) { |sum, v|
        sum[v.username] = {
          id: v.id,
          user_avatar_template: User.avatar_template(v.username, v.uploaded_avatar_id)
        }
        sum
      }

    report.data = []
    num_clicks.each_key do |username|
      report.data << {
        username: username,
        user_id: user_id_lookup[username][:id],
        user_avatar_template: user_id_lookup[username][:user_avatar_template],
        num_clicks: num_clicks[username],
        num_topics: num_topics[username]
      }
    end
    report.data = report.data.sort_by { |x| x[:num_clicks] }.reverse[0, 10]
  end

  def self.per_user(start_date:, end_date:, category_id:)
    @per_user_query ||= public_incoming_links(category_id: category_id)
      .where('incoming_links.created_at > ? AND incoming_links.created_at < ? AND incoming_links.user_id IS NOT NULL', start_date, end_date)
      .joins(:user)
      .group('users.username')
  end

  def self.link_count_per_user(start_date:, end_date:, category_id:)
    per_user(start_date: start_date, end_date: end_date, category_id: category_id).count
  end

  def self.topic_count_per_user(start_date:, end_date:, category_id:)
    per_user(start_date: start_date, end_date: end_date, category_id: category_id).joins(:post).count("DISTINCT posts.topic_id")
  end

  # Return top 10 domains that brought traffic to the site within the last 30 days
  def self.report_top_traffic_sources(report)
    report.y_titles[:num_clicks] = I18n.t("reports.#{report.type}.num_clicks")
    report.y_titles[:num_topics] = I18n.t("reports.#{report.type}.num_topics")
    report.y_titles[:num_users] = I18n.t("reports.#{report.type}.num_users")

    num_clicks = link_count_per_domain(start_date: report.start_date, end_date: report.end_date, category_id: report.category_id)
    num_topics = topic_count_per_domain(num_clicks.keys, category_id: report.category_id)
    report.data = []
    num_clicks.each_key do |domain|
      report.data << { domain: domain, num_clicks: num_clicks[domain], num_topics: num_topics[domain] }
    end
    report.data = report.data.sort_by { |x| x[:num_clicks] }.reverse[0, 10]
  end

  def self.link_count_per_domain(limit: 10, start_date:, end_date:, category_id:)
    public_incoming_links(category_id: category_id)
      .where('incoming_links.created_at > ? AND incoming_links.created_at < ?', start_date, end_date)
      .joins(incoming_referer: :incoming_domain)
      .group('incoming_domains.name')
      .order('count_all DESC')
      .limit(limit)
      .count
  end

  def self.per_domain(domains, options = {})
    public_incoming_links(category_id: options[:category_id])
      .joins(incoming_referer: :incoming_domain)
      .where('incoming_links.created_at > ? AND incoming_domains.name IN (?)', 30.days.ago, domains)
      .group('incoming_domains.name')
  end

  def self.topic_count_per_domain(domains, options = {})
    # COUNT(DISTINCT) is slow
    per_domain(domains, options).count("DISTINCT posts.topic_id")
  end

  def self.report_top_referred_topics(report)
    report.y_titles[:num_clicks] = I18n.t("reports.#{report.type}.labels.num_clicks")
    num_clicks = link_count_per_topic(start_date: report.start_date, end_date: report.end_date, category_id: report.category_id)
    num_clicks = num_clicks.to_a.sort_by { |x| x[1] }.last(report.limit || 10).reverse
    report.data = []
    topics = Topic.select('id, slug, title').where('id in (?)', num_clicks.map { |z| z[0] })
    topics = topics.in_category_and_subcategories(report.category_id) if report.category_id
    num_clicks.each do |topic_id, num_clicks_element|
      topic = topics.find { |t| t.id == topic_id }
      if topic
        report.data << { topic_id: topic_id, topic_title: topic.title, topic_url: topic.relative_url, num_clicks: num_clicks_element }
      end
    end
    report.data
  end

  def self.link_count_per_topic(start_date:, end_date:, category_id:)
    public_incoming_links(category_id: category_id)
      .where('incoming_links.created_at > ? AND incoming_links.created_at < ? AND topic_id IS NOT NULL', start_date, end_date)
      .group('topic_id')
      .count
  end

  def self.public_incoming_links(category_id: nil)
    IncomingLink
      .joins(post: :topic)
      .where("topics.archetype = ?", Archetype.default)
      .merge(Topic.in_category_and_subcategories(category_id))
  end
end
