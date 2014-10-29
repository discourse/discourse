require_dependency 'trust_level'

class AdminUserIndexQuery
  def initialize(params = {}, klass = User, trust_levels = TrustLevel.levels)
    @params = params
    @query = initialize_query_with_order(klass)
    @trust_levels = trust_levels
  end

  attr_reader :params, :trust_levels

  def initialize_query_with_order(klass)
    if params[:query] == "active"
      klass.order("COALESCE(last_seen_at, to_date('1970-01-01', 'YYYY-MM-DD')) DESC, username")
    else
      klass.order("created_at DESC, username")
    end
  end

  def filter_by_trust
    levels = trust_levels.map { |key, _| key.to_s }
    if levels.include?(params[:query])
      @query.where('trust_level = ?', trust_levels[params[:query].to_sym])
    end
  end

  def filter_by_query_classification
    case params[:query]
      when 'admins' then @query.where(admin: true)
      when 'moderators' then @query.where(moderator: true)
      when 'blocked' then @query.blocked
      when 'suspended' then @query.suspended
      when 'pending' then @query.not_suspended.where(approved: false)
    end
  end

  def filter_by_search
    if params[:filter].present?
      if params[:filter] =~ Resolv::IPv4::Regex || params[:filter] =~ Resolv::IPv6::Regex
        @query.where('ip_address = :ip OR registration_ip_address = :ip', ip: params[:filter])
      else
        @query.where('username_lower ILIKE :filter OR email ILIKE :filter', filter: "%#{params[:filter]}%")
      end
    end
  end

  def filter_by_ip
    if params[:ip].present?
      @query.where('ip_address = :ip OR registration_ip_address = :ip', ip: params[:ip])
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

  def find_users
    find_users_query.includes(:user_stat)
                    .includes(:single_sign_on_record)
                    .includes(:facebook_user_info)
                    .includes(:twitter_user_info)
                    .includes(:github_user_info)
                    .includes(:google_user_info)
                    .includes(:oauth2_user_info)
                    .take(100)
  end
end
