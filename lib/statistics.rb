# frozen_string_literal: true

class Statistics
  EU_COUNTRIES = %w[
    AT
    BE
    BG
    CY
    CZ
    DE
    DK
    EE
    ES
    FI
    FR
    GR
    HR
    HU
    IE
    IT
    LT
    LU
    LV
    MT
    NL
    PL
    PT
    RO
    SE
    SI
    SK
  ]

  def self.active_users
    {
      last_day: valid_users.where("last_seen_at > ?", 1.day.ago).count,
      "7_days": valid_users.where("last_seen_at > ?", 7.days.ago).count,
      "30_days": valid_users.where("last_seen_at > ?", 30.days.ago).count,
    }
  end

  def self.likes
    likes = UserAction.where(action_type: UserAction::LIKE)

    {
      last_day: likes.where("created_at > ?", 1.day.ago).count,
      "7_days": likes.where("created_at > ?", 7.days.ago).count,
      "30_days": likes.where("created_at > ?", 30.days.ago).count,
      count: likes.count,
    }
  end

  def self.posts
    {
      last_day: Post.where("created_at > ?", 1.day.ago).count,
      "7_days": Post.where("created_at > ?", 7.days.ago).count,
      "30_days": Post.where("created_at > ?", 30.days.ago).count,
      count: Post.count,
    }
  end

  def self.topics
    topics = Topic.listable_topics

    {
      last_day: topics.where("created_at > ?", 1.day.ago).count,
      "7_days": topics.where("created_at > ?", 7.days.ago).count,
      "30_days": topics.where("created_at > ?", 30.days.ago).count,
      count: topics.count,
    }
  end

  def self.users
    {
      last_day: valid_users.where("created_at > ?", 1.day.ago).count,
      "7_days": valid_users.where("created_at > ?", 7.days.ago).count,
      "30_days": valid_users.where("created_at > ?", 30.days.ago).count,
      count: valid_users.count,
    }
  end

  def self.participating_users
    {
      last_day: participating_users_count(1.day.ago),
      "7_days": participating_users_count(7.days.ago),
      "30_days": participating_users_count(30.days.ago),
    }
  end

  def self.visitors
    periods = [[1.day.ago, :last_day], [7.days.ago, :"7_days"], [30.days.ago, :"30_days"]]

    periods
      .map do |(period, key)|
        anon_page_views =
          ApplicationRequest.request_type_count_for_period(:page_view_anon_browser, period)

        logged_in_visitors = logged_in_visitors_count(period)
        next key, anon_page_views if logged_in_visitors == 0

        logged_in_page_views =
          ApplicationRequest.request_type_count_for_period(:page_view_logged_in_browser, period)
        next key, anon_page_views + logged_in_visitors if logged_in_page_views == 0

        total_visitors = logged_in_visitors
        avg_logged_in_page_view_per_user = logged_in_page_views.to_f / logged_in_visitors
        anon_visitors = (anon_page_views / avg_logged_in_page_view_per_user).round
        total_visitors += anon_visitors
        [key, total_visitors]
      end
      .to_h
  end

  def self.eu_visitors
    periods = [[1.day.ago, :last_day], [7.days.ago, :"7_days"], [30.days.ago, :"30_days"]]

    periods
      .map do |(period, key)|
        logged_in_page_views =
          ApplicationRequest.request_type_count_for_period(:page_view_logged_in_browser, period)
        anon_page_views =
          ApplicationRequest.request_type_count_for_period(:page_view_anon_browser, period)

        all_logged_in_visitors = logged_in_visitors_count(period)
        eu_logged_in_visitors = eu_logged_in_visitors_count(period)

        next key, 0 if all_logged_in_visitors == 0 || eu_logged_in_visitors == 0
        next key, eu_logged_in_visitors if logged_in_page_views == 0

        avg_logged_in_page_view_per_user = logged_in_page_views / all_logged_in_visitors.to_f

        eu_logged_in_visitors_ratio = eu_logged_in_visitors / all_logged_in_visitors.to_f

        eu_anon_visitors =
          ((anon_page_views / avg_logged_in_page_view_per_user) * eu_logged_in_visitors_ratio).round
        eu_visitors = eu_logged_in_visitors + eu_anon_visitors
        [key, eu_visitors]
      end
      .to_h
  end

  private

  def self.valid_users
    users = User.real.activated.not_staged.not_suspended.not_silenced
    users = users.approved if SiteSetting.must_approve_users
    users
  end

  def self.participating_users_count(date)
    subqueries = [
      "SELECT DISTINCT user_id FROM user_actions WHERE created_at > :date AND action_type IN (:action_types)",
    ]

    if ActiveRecord::Base.connection.data_source_exists?("chat_messages")
      subqueries << "SELECT DISTINCT user_id FROM chat_messages WHERE created_at > :date AND deleted_at IS NULL"
    end

    if ActiveRecord::Base.connection.data_source_exists?("chat_message_reactions")
      subqueries << "SELECT DISTINCT user_id FROM chat_message_reactions WHERE created_at > :date"
    end

    sql = <<~SQL
      WITH valid_users AS (#{valid_users.select(:id).to_sql})
      SELECT COUNT(DISTINCT user_id) 
      FROM (#{subqueries.join(" UNION ")}) participating_users
      JOIN valid_users ON valid_users.id = participating_users.user_id
    SQL

    DB.query_single(sql, date: date, action_types: UserAction::USER_ACTED_TYPES).first
  end

  def self.logged_in_visitors_count(since)
    DB.query_single(<<~SQL, since:).first
      SELECT COUNT(DISTINCT user_id)
      FROM user_visits
      WHERE visited_at >= :since
    SQL
  end

  def self.eu_logged_in_visitors_count(since)
    results = DB.query_hash(<<~SQL, since:)
      SELECT DISTINCT(user_id), ip_address
      FROM user_visits uv
      INNER JOIN users u
      ON u.id = uv.user_id
      WHERE visited_at >= :since AND ip_address IS NOT NULL
    SQL

    results.reduce(0) do |sum, hash|
      ip_info = DiscourseIpInfo.get(hash["ip_address"].to_s)
      sum + (EU_COUNTRIES.include?(ip_info[:country_code]) ? 1 : 0)
    end
  end
end
