class IncomingLinksReport

  attr_accessor :type, :data, :y_titles

  def initialize(type)
    @type = type
    @y_titles = {}
    @data = nil
  end

  def as_json
    {
      type: self.type,
      title: I18n.t("reports.#{self.type}.title"),
      xaxis: I18n.t("reports.#{self.type}.xaxis"),
      ytitles: self.y_titles,
      data: self.data
    }
  end

  def self.find(type, opts={})
    report_method = :"report_#{type}"
    return nil unless respond_to?(report_method)

    # Load the report
    report = IncomingLinksReport.new(type)
    send(report_method, report)
    report
  end

  # Return top 10 users who brought traffic to the site within the last 30 days
  def self.report_top_referrers(report)
    report.y_titles[:num_visits]  = I18n.t("reports.#{report.type}.num_visits")
    report.y_titles[:num_topics] = I18n.t("reports.#{report.type}.num_topics")

    num_visits  = link_count_per_user
    num_topics = topic_count_per_user
    report.data = []
    num_visits.keys.each do |username|
      report.data << {username: username, num_visits: num_visits[username], num_topics: num_topics[username]}
    end
    report.data = report.data.sort_by {|x| x[:num_visits]}.reverse[0,10]
  end

  def self.per_user
    @per_user_query ||= IncomingLink.where('incoming_links.created_at > ? AND incoming_links.user_id IS NOT NULL', 30.days.ago).joins(:user).group('users.username')
  end

  def self.link_count_per_user
    per_user.count
  end

  def self.topic_count_per_user
    per_user.count('incoming_links.topic_id', distinct: true)
  end


  # Return top 10 domains that brought traffic to the site within the last 30 days
  def self.report_top_traffic_sources(report)
    report.y_titles[:num_visits]  = I18n.t("reports.#{report.type}.num_visits")
    report.y_titles[:num_topics] = I18n.t("reports.#{report.type}.num_topics")
    report.y_titles[:num_users] = I18n.t("reports.#{report.type}.num_users")

    num_visits  = link_count_per_domain
    num_topics = topic_count_per_domain
    num_users  = user_count_per_domain
    report.data = []
    num_visits.keys.each do |domain|
      report.data << {domain: domain, num_visits: num_visits[domain], num_topics: num_topics[domain], num_users: num_users[domain]}
    end
    report.data = report.data.sort_by {|x| x[:num_visits]}.reverse[0,10]
  end

  def self.per_domain
    @per_domain_query ||= IncomingLink.where('created_at > ? AND domain IS NOT NULL', 30.days.ago).group('domain')
  end

  def self.link_count_per_domain
    per_domain.count
  end

  def self.topic_count_per_domain
    per_domain.count('topic_id', distinct: true)
  end

  def self.user_count_per_domain
    per_domain.count('user_id', distinct: true)
  end


  def self.report_top_referred_topics(report)
    report.y_titles[:num_visits]  = I18n.t("reports.#{report.type}.num_visits")
    num_visits  = link_count_per_topic
    num_visits = num_visits.to_a.sort_by {|x| x[1]}.last(10).reverse # take the top 10
    report.data = []
    topics = Topic.select('id, slug, title').where('id in (?)', num_visits.map {|z| z[0]}).all
    num_visits.each do |topic_id, num_visits|
      topic = topics.find {|t| t.id == topic_id}
      if topic
        report.data << {topic_id: topic_id, topic_title: topic.title, topic_slug: topic.slug, num_visits: num_visits}
      end
    end
    report.data
  end

  def self.link_count_per_topic
    IncomingLink.where('created_at > ? AND topic_id IS NOT NULL', 30.days.ago).group('topic_id').count
  end
end