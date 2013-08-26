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
    levels = trust_levels.map { |key, value| key.to_s }
    if levels.include?(params[:query])
      @query.where('trust_level = ?', trust_levels[params[:query].to_sym])
    end
  end

  def filter_by_query_classification
    case params[:query]
      when 'admins' then @query.where('admin = ?', true)
      when 'moderators' then @query.where('moderator = ?', true)
      when 'blocked' then @query.blocked
      when 'banned' then @query.banned
      when 'pending' then @query.not_banned.where('approved = false')
    end
  end

  def filter_by_search
    if params[:filter].present?
      @query.where('username_lower ILIKE :filter or email ILIKE :filter', filter: "%#{params[:filter]}%")
    end
  end

  # this might not be needed in rails 4 ?
  def append(active_relation)
    @query = active_relation if active_relation
  end

  def find_users_query
    append filter_by_trust
    append filter_by_query_classification
    append filter_by_search
    @query
  end

  def find_users
    find_users_query.take(100)
  end
end
