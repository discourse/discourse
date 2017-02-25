require_dependency 'trust_level'

class AdminUserIndexQuery

  def initialize(params = {}, klass = User, trust_levels = TrustLevel.levels)
    @params = params
    @query = initialize_query_with_order(klass)
    @trust_levels = trust_levels
  end

  attr_reader :params, :trust_levels

  def find_users(limit=100)
    find_users_query.limit(limit)
  end

  def count_users
    find_users_query.count
  end

  def self.orderable_user_columns
    %w(created_at trust_level last_emailed_at last_seen_at username email)
  end
  
  def self.orderable_stat_columns
    %w(days_visited posts_read_count topics_entered post_count time_read)
  end

  def custom_direction
    asc = params[:ascending]
    asc.present? && asc ? "ASC" : "DESC"
  end

  def pg_coalesce(column)
    "COALESCE(#{column}, to_date('1970-01-01', 'YYYY-MM-DD'))"
  end

  def initialize_query_with_order(klass)
    order = []

    custom_order = params[:order]
    if custom_order.present? &&
      without_dir = custom_order.downcase.sub(/ (asc|desc)$/, '')
      if AdminUserIndexQuery.orderable_user_columns.include?(without_dir)
        without_dir = (without_dir == "last_seen_at") ? pg_coalesce("last_seen_at") : without_dir
        without_dir = (without_dir == "last_emailed_at") ? pg_coalesce("last_emailed_at") : without_dir
        order << "#{without_dir} #{custom_direction}"
      end
      if AdminUserIndexQuery.orderable_stat_columns.include?(without_dir)
        order << "user_stats.#{without_dir} #{custom_direction}"
      end
    end
    
    if !custom_order.present?
      if params[:query] == "active"
        order << "#{pg_coalesce("last_seen_at")} DESC"
      else
        order << "users.created_at DESC"
      end

      order << "users.username"
    end

    if params[:stats].present? && params[:stats] == false
      klass.order(order.reject(&:blank?).join(","))
    else
      klass.includes(:user_stat).order(order.reject(&:blank?).join(","))
    end
  end

  def filter_by_trust
    levels = trust_levels.map { |key, _| key.to_s }
    if levels.include?(params[:query])
      @query.where('trust_level = ?', trust_levels[params[:query].to_sym])
    end
  end

  def suspect_users
    where_conds = []

    # One signal: no reading yet the user has bio text
    where_conds << "user_stats.posts_read_count <= 1 AND user_stats.topics_entered <= 1"

    @query.activated
          .references(:user_stats)
          .includes(:user_profile)
          .where("COALESCE(user_profiles.bio_raw, '') != ''")
          .where('users.created_at <= ?', 1.day.ago)
          .where(where_conds.map {|c| "(#{c})"}.join(" OR "))
  end

  def filter_by_query_classification
    case params[:query]
      when 'staff'      then @query.where("admin or moderator")
      when 'admins'     then @query.where(admin: true)
      when 'moderators' then @query.where(moderator: true)
      when 'blocked'    then @query.blocked
      when 'suspended'  then @query.suspended
      when 'pending'    then @query.not_suspended.where(approved: false)
      when 'suspect'    then suspect_users
    end
  end

  def filter_by_search
    if params[:filter].present?
      params[:filter].strip!
      if ip = IPAddr.new(params[:filter]) rescue nil
        @query.where('ip_address <<= :ip OR registration_ip_address <<= :ip', ip: ip.to_cidr_s)
      else
        @query.where('username_lower ILIKE :filter OR email ILIKE :filter', filter: "%#{params[:filter]}%")
      end
    end
  end

  def filter_by_ip
    if params[:ip].present?
      @query.where('ip_address = :ip OR registration_ip_address = :ip', ip: params[:ip].strip)
    end
  end

  def filter_exclude
    if params[:exclude].present?
      @query.where('id != ?', params[:exclude])
    end
  end

  # this might not be needed in rails 4 ?
  def append(active_relation)
    @query = active_relation if active_relation
  end

  def find_users_query
    append filter_by_trust
    append filter_by_query_classification
    append filter_by_ip
    append filter_exclude
    append filter_by_search
    @query
  end

end
