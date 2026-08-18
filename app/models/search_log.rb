# frozen_string_literal: true

class SearchLog < ActiveRecord::Base
  MAXIMUM_USER_AGENT_LENGTH = 2000
  MAXIMUM_SESSION_ID_LENGTH = BrowserPageviewEvent::MAX_SESSION_ID_LENGTH

  validates :term, presence: true
  validates :user_agent, length: { maximum: MAXIMUM_USER_AGENT_LENGTH }

  belongs_to :user

  scope :non_staff, -> { joins(:user).where(users: { admin: false, moderator: false }) }
  scope :non_staff_or_anonymous,
        -> do
          left_outer_joins(:user).where(
            "users.id IS NULL OR (NOT users.admin AND NOT users.moderator)",
          )
        end
  scope :excluding_crawlers,
        -> do
          scope = where(crawler: false)
          CrawlerScorer.enabled? ? scope.where(likely_crawler: false) : scope
        end
  scope :human_only, -> { non_staff_or_anonymous.excluding_crawlers }

  def ctr
    return 0 if click_through == 0 || searches == 0

    ((click_through.to_f / searches.to_f) * 100).ceil(1)
  end

  def self.search_types
    @search_types ||= Enum.new(header: 1, full_page: 2)
  end

  def self.search_result_types
    @search_result_types ||= Enum.new(topic: 1, user: 2, category: 3, tag: 4)
  end

  def self.redis_key(ip_address:, user_id: nil)
    if user_id
      "__SEARCH__LOG_#{user_id}"
    else
      "__SEARCH__LOG_#{ip_address}"
    end
  end

  # for testing
  def self.clear_debounce_cache!
    Discourse.redis.keys("__SEARCH__LOG_*").each { |k| Discourse.redis.del(k) }
  end

  def self.log(term:, search_type:, ip_address:, user_agent: nil, user_id: nil, session_id: nil)
    return [:error] if term.blank?

    can_log_search =
      DiscoursePluginRegistry.apply_modifier(:search_log_can_log, term: term, user_id: user_id)
    return if !can_log_search

    search_type = search_types[search_type]
    return [:error] if search_type.blank? || ip_address.blank?

    ip_address = nil if user_id
    key = redis_key(user_id: user_id, ip_address: ip_address)

    if user_agent && user_agent.length > MAXIMUM_USER_AGENT_LENGTH
      user_agent = user_agent.truncate(MAXIMUM_USER_AGENT_LENGTH, omission: "")
    end

    result = nil

    if existing = Discourse.redis.get(key)
      id, old_term = existing.split(",", 2)

      if term.start_with?(old_term)
        where(id: id.to_i).update_all(created_at: Time.zone.now, term: term)

        result = [:updated, id.to_i]
      end
    end

    if !result
      log =
        create!(
          term: term,
          search_type: search_type,
          ip_address: ip_address,
          user_agent: user_agent,
          user_id: user_id,
          session_id: session_id&.slice(0, MAXIMUM_SESSION_ID_LENGTH),
          crawler: user_agent.present? && CrawlerDetection.crawler?(user_agent),
        )

      result = [:created, log.id]
    end

    Discourse.redis.setex(key, 5, "#{result[1]},#{term}")

    result
  end

  BACKFILL_AGENT_BATCH_SIZE = 100

  def self.backfill_crawler!
    agents = DB.query_single(<<~SQL)
      SELECT DISTINCT user_agent
      FROM search_logs
      WHERE NOT crawler
        AND user_agent IS NOT NULL
        AND user_agent <> ''
    SQL

    crawler_agents = agents.select { |agent| CrawlerDetection.crawler?(agent) }
    return 0 if crawler_agents.empty?

    crawler_agents
      .each_slice(BACKFILL_AGENT_BATCH_SIZE)
      .sum { |batch| DB.exec(<<~SQL, agents: batch) }
        UPDATE search_logs
        SET crawler = TRUE
        WHERE NOT crawler
          AND user_agent IN (:agents)
      SQL
  end

  def self.flag_likely_crawlers!(window_start:, window_end:)
    DB.exec(<<~SQL, window_start: window_start, window_end: window_end)
        UPDATE search_logs
        SET likely_crawler = TRUE
        WHERE NOT search_logs.likely_crawler
          AND search_logs.session_id IS NOT NULL
          AND search_logs.created_at >= :window_start
          AND search_logs.created_at < :window_end
          AND EXISTS (
            SELECT 1
            FROM browser_pageview_events event
            WHERE event.session_id = search_logs.session_id
              AND #{CrawlerScorer.likely_crawler_condition(table: "event")}
          )
      SQL
  end

  def self.term_details(term, period = :weekly, search_type = :all)
    details = []

    result =
      SearchLog.select("COUNT(*) AS count, search_logs.created_at::date AS date").where(
        "lower(search_logs.term) = ? AND search_logs.created_at > ?",
        term.downcase,
        start_of(period),
      )

    result = result.where("search_type = ?", search_types[search_type]) if search_type == :header ||
      search_type == :full_page
    result = result.where.not(search_result_id: nil) if search_type == :click_through_only
    result = result.non_staff if search_type == :non_staff_only
    result = result.human_only if search_type == :human_only

    result
      .order("date")
      .group("search_logs.created_at::date")
      .each { |record| details << { x: Date.parse(record["date"].to_s), y: record["count"] } }

    {
      type: "search_log_term",
      title: I18n.t("search_logs.graph_title"),
      start_date: start_of(period),
      end_date: Time.zone.now,
      data: details,
      period: period.to_s,
    }
  end

  def self.trending(period = :all, search_type = :all)
    SearchLog.trending_from(start_of(period), search_type: search_type)
  end

  def self.trending_from(start_date, options = {})
    end_date = options[:end_date]
    search_type = options[:search_type] || :all
    limit = options[:limit] || 100

    select_sql = <<~SQL
      lower(term) term,
      COUNT(*) AS searches,
      SUM(CASE
               WHEN search_result_id IS NOT NULL THEN 1
               ELSE 0
           END) AS click_through
    SQL

    result = SearchLog.select(select_sql).where("search_logs.created_at > ?", start_date)

    result = result.where("search_logs.created_at < ?", end_date) if end_date

    if search_type == :non_staff_only
      result = result.non_staff
    elsif search_type == :human_only
      result = result.human_only
    elsif search_type != :all
      result = result.where("search_type = ?", search_types[search_type])
    end

    result.group("lower(term)").order("searches DESC, click_through DESC, term ASC").limit(limit)
  end

  def self.clean_up
    search_id =
      SearchLog.order(:id).offset(SiteSetting.search_query_log_max_size).limit(1).pluck(:id)
    SearchLog.where("id < ?", search_id[0]).delete_all if search_id.present?
    SearchLog.where(
      "created_at < TIMESTAMP ?",
      SiteSetting.search_query_log_max_retention_days.days.ago,
    ).delete_all
  end

  def self.start_of(period)
    period =
      case period
      when :yearly
        1.year.ago
      when :monthly
        1.month.ago
      when :quarterly
        3.months.ago
      when :weekly
        1.week.ago
      when :daily
        Time.zone.now
      else
        1000.years.ago
      end

    period&.to_date
  end
  private_class_method :start_of
end

# == Schema Information
#
# Table name: search_logs
#
#  id                 :integer          not null, primary key
#  crawler            :boolean          default(FALSE), not null
#  ip_address         :inet
#  likely_crawler     :boolean          default(FALSE), not null
#  search_result_type :integer
#  search_type        :integer          not null
#  session_id         :string(32)
#  term               :string           not null
#  user_agent         :string(2000)
#  created_at         :datetime         not null
#  search_result_id   :integer
#  user_id            :integer
#
# Indexes
#
#  index_search_logs_on_created_at                     (created_at)
#  index_search_logs_on_created_at_excluding_crawlers  (created_at) WHERE ((NOT crawler) AND (NOT likely_crawler))
#  index_search_logs_on_user_id_and_created_at         (user_id,created_at) WHERE (user_id IS NOT NULL)
#
