# frozen_string_literal: true

class IncomingLinksReport
  attr_accessor :type,
                :data,
                :y_titles,
                :start_date,
                :end_date,
                :limit,
                :category_id,
                :include_subcategories,
                :current_user

  def initialize(type)
    @type = type
    @y_titles = {}
    @data = nil
    @category_id = nil
    @include_subcategories = false
  end

  def as_json(_options = nil)
    {
      type: type,
      title: I18n.t("reports.#{type}.title"),
      xaxis: I18n.t("reports.#{type}.xaxis"),
      ytitles: y_titles,
      data: data,
      start_date: start_date,
      end_date: end_date,
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
    report.include_subcategories = _opts[:include_subcategories] if _opts[:include_subcategories]
    report.current_user = _opts[:current_user] if _opts[:current_user]

    public_send(report_method, report)
    report
  end

  # Return top 10 users who brought traffic to the site within the last 30 days
  def self.report_top_referrers(report)
    report.y_titles[:num_clicks] = I18n.t("reports.#{report.type}.num_clicks")
    report.y_titles[:num_topics] = I18n.t("reports.#{report.type}.num_topics")
    guardian = Guardian.new(report.current_user)

    num_clicks =
      link_count_per_user(
        start_date: report.start_date,
        end_date: report.end_date,
        category_id: report.category_id,
        include_subcategories: report.include_subcategories,
        guardian: guardian,
      )
    num_topics =
      topic_count_per_user(
        start_date: report.start_date,
        end_date: report.end_date,
        category_id: report.category_id,
        include_subcategories: report.include_subcategories,
        guardian: guardian,
      )
    user_id_lookup =
      User
        .where(username: num_clicks.keys)
        .select(:id, :username, :uploaded_avatar_id)
        .inject({}) do |sum, v|
          sum[v.username] = {
            id: v.id,
            user_avatar_template: User.avatar_template(v.username, v.uploaded_avatar_id),
          }
          sum
        end

    report.data = []
    num_clicks.each_key do |username|
      report.data << {
        username: username,
        user_id: user_id_lookup[username][:id],
        user_avatar_template: user_id_lookup[username][:user_avatar_template],
        num_clicks: num_clicks[username],
        num_topics: num_topics[username],
      }
    end
    report.data = report.data.sort_by { |x| x[:num_clicks] }.reverse[0, 10]
  end

  def self.per_user(
    start_date:,
    end_date:,
    category_id:,
    include_subcategories:,
    guardian: Guardian.new
  )
    public_incoming_links(
      category_id: category_id,
      include_subcategories: include_subcategories,
      guardian: guardian,
    )
      .where(
        "incoming_links.created_at > ? AND incoming_links.created_at < ? AND incoming_links.user_id IS NOT NULL",
        start_date,
        end_date,
      )
      .joins(:user)
      .group("users.username")
  end

  def self.link_count_per_user(
    start_date:,
    end_date:,
    category_id:,
    include_subcategories:,
    guardian: Guardian.new
  )
    per_user(
      start_date: start_date,
      end_date: end_date,
      category_id: category_id,
      include_subcategories: include_subcategories,
      guardian: guardian,
    ).count
  end

  def self.topic_count_per_user(
    start_date:,
    end_date:,
    category_id:,
    include_subcategories:,
    guardian: Guardian.new
  )
    per_user(
      start_date: start_date,
      end_date: end_date,
      category_id: category_id,
      include_subcategories: include_subcategories,
      guardian: guardian,
    ).joins(:post).count("DISTINCT posts.topic_id")
  end

  # Return top 10 domains that brought traffic to the site within the last 30 days
  def self.report_top_traffic_sources(report)
    report.y_titles[:num_clicks] = I18n.t("reports.#{report.type}.num_clicks")
    report.y_titles[:num_topics] = I18n.t("reports.#{report.type}.num_topics")
    report.y_titles[:num_users] = I18n.t("reports.#{report.type}.num_users")
    guardian = Guardian.new(report.current_user)

    num_clicks =
      link_count_per_domain(
        start_date: report.start_date,
        end_date: report.end_date,
        category_id: report.category_id,
        include_subcategories: report.include_subcategories,
        guardian: guardian,
      )
    num_topics =
      topic_count_per_domain(
        num_clicks.keys,
        category_id: report.category_id,
        include_subcategories: report.include_subcategories,
        start_date: report.start_date,
        end_date: report.end_date,
        guardian: guardian,
      )
    report.data = []
    num_clicks.each_key do |domain|
      report.data << {
        domain: domain,
        num_clicks: num_clicks[domain],
        num_topics: num_topics[domain],
      }
    end
    report.data = report.data.sort_by { |x| x[:num_clicks] }.reverse[0, 10]
  end

  def self.link_count_per_domain(
    limit: 10,
    start_date:,
    end_date:,
    category_id:,
    include_subcategories:,
    guardian: Guardian.new
  )
    public_incoming_links(
      category_id: category_id,
      include_subcategories: include_subcategories,
      guardian: guardian,
    )
      .where(
        "incoming_links.created_at > ? AND incoming_links.created_at < ?",
        start_date,
        end_date,
      )
      .joins(incoming_referer: :incoming_domain)
      .group("incoming_domains.name")
      .order("count_all DESC")
      .limit(limit)
      .count
  end

  def self.per_domain(domains, options = {})
    public_incoming_links(
      category_id: options[:category_id],
      include_subcategories: options[:include_subcategories],
      guardian: options[:guardian] || Guardian.new,
    )
      .joins(incoming_referer: :incoming_domain)
      .where(
        "incoming_links.created_at > ? AND incoming_links.created_at < ?",
        options[:start_date],
        options[:end_date],
      )
      .where("incoming_domains.name IN (?)", domains)
      .group("incoming_domains.name")
  end

  def self.topic_count_per_domain(domains, options = {})
    # COUNT(DISTINCT) is slow
    per_domain(domains, options).count("DISTINCT posts.topic_id")
  end

  def self.report_top_referred_topics(report)
    report.y_titles[:num_clicks] = I18n.t("reports.#{report.type}.labels.num_clicks")
    guardian = Guardian.new(report.current_user)

    num_clicks =
      link_count_per_topic(
        start_date: report.start_date,
        end_date: report.end_date,
        category_id: report.category_id,
        include_subcategories: report.include_subcategories,
        guardian: guardian,
      )
    num_clicks = num_clicks.to_a.sort_by { |x| x[1] }.last(report.limit || 10).reverse
    report.data = []
    topics = Topic.select(:id, :slug, :title).where(id: num_clicks.map(&:first))
    topics = topics.merge(Topic.secured(guardian))
    if report.category_id
      topics =
        topics.where(
          category_id:
            (
              if report.include_subcategories
                Category.subcategory_ids(report.category_id)
              else
                report.category_id
              end
            ),
        )
    end
    num_clicks.each do |topic_id, num_clicks_element|
      topic = topics.find { |t| t.id == topic_id }
      if topic
        report.data << {
          topic_id: topic_id,
          topic_title: topic.title,
          topic_url: topic.relative_url,
          num_clicks: num_clicks_element,
        }
      end
    end
    report.data
  end

  def self.link_count_per_topic(
    start_date:,
    end_date:,
    category_id:,
    include_subcategories:,
    guardian: Guardian.new
  )
    public_incoming_links(
      category_id: category_id,
      include_subcategories: include_subcategories,
      guardian: guardian,
    )
      .where(
        "incoming_links.created_at > ? AND incoming_links.created_at < ? AND topic_id IS NOT NULL",
        start_date,
        end_date,
      )
      .group("topic_id")
      .count
  end

  def self.public_incoming_links(
    category_id: nil,
    include_subcategories: nil,
    guardian: Guardian.new
  )
    guardian ||= Guardian.new
    links =
      IncomingLink
        .joins(post: :topic)
        .where("topics.archetype = ?", Archetype.default)
        .merge(Topic.secured(guardian))

    if category_id
      if include_subcategories
        links = links.where("topics.category_id IN (?)", Category.subcategory_ids(category_id))
      else
        links = links.where("topics.category_id = ?", category_id)
      end
    end

    links
  end
end
