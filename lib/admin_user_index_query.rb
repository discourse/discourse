# frozen_string_literal: true

class AdminUserIndexQuery
  def initialize(params = {}, klass = User, trust_levels = TrustLevel.levels)
    @params = params
    @query = initialize_query_with_order(klass)
    @trust_levels = trust_levels
  end

  attr_reader :params, :trust_levels

  SORTABLE_MAPPING = {
    "created" => "created_at",
    "last_emailed" => "COALESCE(last_emailed_at, to_date('1970-01-01', 'YYYY-MM-DD'))",
    "seen" => "COALESCE(last_seen_at, to_date('1970-01-01', 'YYYY-MM-DD'))",
    "username" => "username",
    "email" => "email",
    "trust_level" => "trust_level",
    "days_visited" => "user_stats.days_visited",
    "posts_read" => "user_stats.posts_read_count",
    "topics_viewed" => "user_stats.topics_entered",
    "posts" => "user_stats.post_count",
    "read_time" => "user_stats.time_read",
    "silence_reason" => "silence_reason",
  }

  def find_users(limit = 100)
    page = params[:page].to_i - 1
    page = 0 if page < 0
    find_users_query.limit(limit).offset(page * limit)
  end

  def count_users
    find_users_query.count
  end

  def initialize_query_with_order(klass)
    order = []

    custom_order = params[:order]
    custom_direction = params[:asc].present? ? "ASC" : "DESC"
    if custom_order.present? &&
         without_dir = SORTABLE_MAPPING[custom_order.downcase.sub(/ (asc|desc)\z/, "")]
      order << "#{without_dir} #{custom_direction} NULLS LAST"
    end

    if !custom_order.present?
      if params[:query] == "active"
        order << "users.last_seen_at DESC NULLS LAST"
      else
        order << "users.created_at DESC"
      end

      order << "users.username"
    end

    query = klass.includes(:totps).order(order.reject(&:blank?).join(","))

    query = query.includes(:user_stat) unless params[:stats].present? && params[:stats] == false

    query = query.joins(:primary_email) if params[:show_emails] == "true"

    query
  end

  def filter_by_trust
    levels = trust_levels.map { |key, _| key.to_s }
    if levels.include?(params[:query])
      @query.where("trust_level = ?", trust_levels[params[:query].to_sym])
    end
  end

  def filter_by_query_classification
    case params[:query]
    when "staff"
      @query.where("admin or moderator")
    when "admins"
      @query.where(admin: true)
    when "moderators"
      @query.where(moderator: true)
    when "silenced"
      @query.silenced
    when "suspended"
      @query.suspended
    when "pending"
      @query.not_suspended.where(approved: false, active: true)
    when "staged"
      @query.where(staged: true)
    end
  end

  def filter_by_search
    if params[:email].present?
      return @query.joins(:primary_email).where("user_emails.email = ?", params[:email].downcase)
    end

    filter = params[:filter]
    if filter.present?
      filter = filter.strip
      if ip =
           begin
             IPAddr.new(filter)
           rescue StandardError
             nil
           end
        @query.where("ip_address <<= :ip OR registration_ip_address <<= :ip", ip: ip.to_cidr_s)
      else
        @query.filter_by_username_or_email(filter)
      end
    end
  end

  def filter_by_ip
    if params[:ip].present?
      @query.where("ip_address = :ip OR registration_ip_address = :ip", ip: params[:ip].strip)
    end
  end

  def filter_exclude
    @query.where("users.id != ?", params[:exclude]) if params[:exclude].present?
  end

  def append(active_relation)
    @query = active_relation if active_relation
  end

  def with_silence_reason
    @query.joins(
      "LEFT JOIN LATERAL (
        SELECT user_histories.details silence_reason
        FROM user_histories
        WHERE user_histories.target_user_id = users.id
        AND user_histories.action = #{UserHistory.actions[:silence_user]}
        AND users.silenced_till IS NOT NULL
        ORDER BY user_histories.created_at DESC
        LIMIT 1
      ) user_histories ON true",
    )
  end

  def find_users_query
    append filter_by_trust
    append filter_by_query_classification
    append filter_by_ip
    append filter_exclude
    append filter_by_search
    append with_silence_reason
    @query
  end
end
