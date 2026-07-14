# frozen_string_literal: true

class AdminUserIndexQuery
  def initialize(
    params = {},
    klass = User,
    trust_levels = TrustLevel.levels,
    guardian: nil,
    **kwargs
  )
    @params = params.merge(kwargs)
    @query = initialize_query_with_order(klass)
    @trust_levels = trust_levels
    @guardian = guardian
  end

  attr_reader :params, :trust_levels, :guardian

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
    "suspend_reason" => "suspend_reason",
  }

  SAME_IP_ADDRESS_COLUMNS = { "last" => :ip_address, "registration" => :registration_ip_address }

  FILTER_SPLIT_REGEX = /[,\s]+/
  MAX_FILTER_TERMS = 100

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
    if custom_order.present? && without_dir = SORTABLE_MAPPING[normalized_order]
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

  def filter_by_activation
    case params[:activation]
    when "activated"
      @query.activated
    when "not_activated"
      @query.not_activated
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
    return if filter.blank?

    terms = filter.split(FILTER_SPLIT_REGEX).reject(&:blank?)
    return if terms.empty?
    raise Discourse::InvalidParameters.new(:filter) if terms.size > MAX_FILTER_TERMS

    if terms.size == 1
      term = terms.first
      if ip = parse_ip(term)
        return if params[:same_ip_user_id].present?
        return @query.none unless can_see_ip?

        @query.where("ip_address <<= :ip OR registration_ip_address <<= :ip", ip: ip.to_cidr_s)
      else
        @query.filter_by_username_or_email(term)
      end
    else
      filter_by_multiple_terms(terms.map(&:downcase))
    end
  end

  # per-term semantics match the single-term search: substring match on
  # username and primary email, exact match on any email (secondary
  # included) for terms that look like emails
  def filter_by_multiple_terms(terms)
    patterns = terms.map { |term| "%#{term}%" }

    sql = +<<~SQL
      username_lower ILIKE ANY (ARRAY[:patterns])
      OR lower(user_emails.email) ILIKE ANY (ARRAY[:patterns])
    SQL
    binds = { patterns: patterns }

    exact_emails = terms.select { |term| term =~ /.+@.+/ }
    if exact_emails.present?
      sql << "OR users.id IN (SELECT user_id FROM user_emails WHERE lower(user_emails.email) IN (:exact_emails))"
      binds[:exact_emails] = exact_emails
    end

    @query.joins(:primary_email).where(sql, binds)
  end

  def filter_by_ip
    if params[:ip].present?
      return if params[:same_ip_user_id].present?
      return @query.none unless can_see_ip?

      @query.where("ip_address = :ip OR registration_ip_address = :ip", ip: params[:ip].strip)
    end
  end

  def filter_by_same_ip_user
    if params[:same_ip_user_id].present?
      if same_ip_address.present?
        @query.where("ip_address = :ip OR registration_ip_address = :ip", ip: same_ip_address.to_s)
      else
        @query.none
      end
    end
  end

  def same_ip_target_user
    return @same_ip_target_user if defined?(@same_ip_target_user)
    @same_ip_target_user = User.find_by(id: params[:same_ip_user_id])
  end

  def same_ip_address
    @same_ip_address ||= same_ip_target_user&.public_send(same_ip_address_column)
  end

  def filter_exclude
    @query.where.not(id: params[:exclude]) if params[:exclude].present?
  end

  def append(active_relation)
    @query = active_relation if active_relation
  end

  def same_ip_address_column
    SAME_IP_ADDRESS_COLUMNS.fetch(params[:ip_type].presence, :ip_address)
  end

  def parse_ip(filter)
    IPAddr.new(filter)
  rescue StandardError
    nil
  end

  def can_see_ip?
    guardian&.can_see_ip?
  end

  def with_penalty_reason(action, till_column, name)
    @query.joins(<<~SQL)
      LEFT JOIN LATERAL (
        SELECT user_histories.details #{name}
        FROM user_histories
        WHERE user_histories.target_user_id = users.id
          AND user_histories.action = #{UserHistory.actions[action]}
          AND users.#{till_column} IS NOT NULL
        ORDER BY user_histories.id DESC
        LIMIT 1
      ) #{name}s ON true
    SQL
  end

  def penalty_reasons(users, action)
    return {} if users.empty?

    UserHistory
      .where(action: UserHistory.actions[action], target_user_id: users.map(&:id))
      .order(:target_user_id, id: :desc)
      .select(Arel.sql("DISTINCT ON (target_user_id) target_user_id, details"))
      .each_with_object({}) { |record, hash| hash[record.target_user_id] = record.details }
  end

  def normalized_order
    params[:order]&.downcase&.sub(/ (asc|desc)\z/, "")
  end

  def sorting_by?(column)
    normalized_order == column
  end

  def find_users_query
    append filter_by_trust
    append filter_by_query_classification
    append filter_by_activation
    append filter_by_ip
    append filter_by_same_ip_user
    append filter_exclude
    append filter_by_search

    if sorting_by?("silence_reason")
      append with_penalty_reason(:silence_user, :silenced_till, "silence_reason")
    elsif sorting_by?("suspend_reason")
      append with_penalty_reason(:suspend_user, :suspended_till, "suspend_reason")
    end

    @query
  end
end
