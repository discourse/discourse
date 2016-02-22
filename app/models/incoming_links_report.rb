class IncomingLinksReport

  attr_accessor :type, :data, :y_titles

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
      data: self.data
    }
  end

  def self.find(type, _opts = {})
    report_method = :"report_#{type}"
    return nil unless respond_to?(report_method)

    # Load the report
    report = IncomingLinksReport.new(type)
    send(report_method, report)
    report
  end

  # Return top 10 users who brought traffic to the site within the last 30 days
  def self.report_top_referrers(report)
    report.y_titles[:num_clicks]  = I18n.t("reports.#{report.type}.num_clicks")
    report.y_titles[:num_topics] = I18n.t("reports.#{report.type}.num_topics")

    num_clicks  = link_count_per_user
    num_topics = topic_count_per_user
    user_id_lookup = User.where(username: num_clicks.keys).select(:id, :username).inject({}) {|sum,v| sum[v.username] = v.id; sum;}
    report.data = []
    num_clicks.each_key do |username|
      report.data << {username: username, user_id: user_id_lookup[username], num_clicks: num_clicks[username], num_topics: num_topics[username]}
    end
    report.data = report.data.sort_by {|x| x[:num_clicks]}.reverse[0,10]
  end

  def self.per_user
    @per_user_query ||= IncomingLink
        .where('incoming_links.created_at > ? AND incoming_links.user_id IS NOT NULL', 30.days.ago)
        .joins(:user)
        .group('users.username')
  end

  def self.link_count_per_user
    per_user.count
  end

  def self.topic_count_per_user
    per_user.joins(:post).count("DISTINCT posts.topic_id")
  end


  # Return top 10 domains that brought traffic to the site within the last 30 days
  def self.report_top_traffic_sources(report)
    report.y_titles[:num_clicks]  = I18n.t("reports.#{report.type}.num_clicks")
    report.y_titles[:num_topics] = I18n.t("reports.#{report.type}.num_topics")
    report.y_titles[:num_users] = I18n.t("reports.#{report.type}.num_users")

    num_clicks  = link_count_per_domain
    num_topics = topic_count_per_domain(num_clicks.keys)
    report.data = []
    num_clicks.each_key do |domain|
      report.data << {domain: domain, num_clicks: num_clicks[domain], num_topics: num_topics[domain]}
    end
    report.data = report.data.sort_by {|x| x[:num_clicks]}.reverse[0,10]
  end

  def self.link_count_per_domain(limit=10)
    IncomingLink.where('incoming_links.created_at > ?', 30.days.ago)
                .joins(:incoming_referer => :incoming_domain)
                .group('incoming_domains.name')
                .order('count_all DESC')
                .limit(limit).count
  end

  def self.per_domain(domains)
    IncomingLink
        .joins(:incoming_referer => :incoming_domain)
        .where('incoming_links.created_at > ? AND incoming_domains.name IN (?)', 30.days.ago, domains)
        .group('incoming_domains.name')
  end

  def self.topic_count_per_domain(domains)
    # COUNT(DISTINCT) is slow
    per_domain(domains).joins(:post).count("DISTINCT posts.topic_id")
  end


  def self.report_top_referred_topics(report)
    report.y_titles[:num_clicks]  = I18n.t("reports.#{report.type}.num_clicks")
    num_clicks  = link_count_per_topic
    num_clicks = num_clicks.to_a.sort_by {|x| x[1]}.last(10).reverse # take the top 10
    report.data = []
    topics = Topic.select('id, slug, title').where('id in (?)', num_clicks.map {|z| z[0]})
    num_clicks.each do |topic_id, num_clicks_element|
      topic = topics.find {|t| t.id == topic_id}
      if topic
        report.data << {topic_id: topic_id, topic_title: topic.title, topic_slug: topic.slug, num_clicks: num_clicks_element}
      end
    end
    report.data
  end

  def self.link_count_per_topic
    IncomingLink.joins(:post)
                .where('incoming_links.created_at > ? AND topic_id IS NOT NULL', 30.days.ago)
                .group('topic_id')
                .count
  end
end
