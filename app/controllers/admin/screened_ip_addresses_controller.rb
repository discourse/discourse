require_dependency 'ip_addr'

class Admin::ScreenedIpAddressesController < Admin::AdminController

  before_filter :fetch_screened_ip_address, only: [:update, :destroy]

  def index
    filter = params[:filter]
    filter = IPAddr.handle_wildcards(filter)

    screened_ip_addresses = ScreenedIpAddress
    screened_ip_addresses = screened_ip_addresses.where("cidr '#{filter}' >>= ip_address") if filter.present?
    screened_ip_addresses = screened_ip_addresses.limit(200).order('match_count desc')

    begin
      screened_ip_addresses = screened_ip_addresses.to_a
    rescue ActiveRecord::StatementInvalid
      # postgresql throws a PG::InvalidTextRepresentation exception when filter isn't a valid cidr expression
      screened_ip_addresses = []
    end

    render_serialized(screened_ip_addresses, ScreenedIpAddressSerializer)
  end

  def create
    screened_ip_address = ScreenedIpAddress.new(allowed_params)
    if screened_ip_address.save
      render_serialized(screened_ip_address, ScreenedIpAddressSerializer)
    else
      render_json_error(screened_ip_address)
    end
  end

  def update
    if @screened_ip_address.update_attributes(allowed_params)
      render json: success_json
    else
      render_json_error(@screened_ip_address)
    end
  end

  def destroy
    @screened_ip_address.destroy
    render json: success_json
  end

  def star_subnets_query
    @star_subnets_query ||= <<-SQL
      SELECT network(inet(host(ip_address) || '/24')) AS ip_range
        FROM screened_ip_addresses
       WHERE action_type = #{ScreenedIpAddress.actions[:block]}
         AND family(ip_address) = 4
         AND masklen(ip_address) = 32
    GROUP BY ip_range
      HAVING COUNT(*) >= :min_count
    SQL
  end

  def star_star_subnets_query
    @star_star_subnets_query ||= <<-SQL
      WITH weighted_subnets AS (
        SELECT network(inet(host(ip_address) || '/16')) AS ip_range,
               CASE masklen(ip_address)
                 WHEN 32 THEN 1
                 WHEN 24 THEN :roll_up_weight
                 ELSE 0
               END AS weight
          FROM screened_ip_addresses
         WHERE action_type = #{ScreenedIpAddress.actions[:block]}
           AND family(ip_address) = 4
      )
      SELECT ip_range
        FROM weighted_subnets
    GROUP BY ip_range
      HAVING SUM(weight) >= :min_count
    SQL
  end

  def star_subnets
    min_count = SiteSetting.min_ban_entries_for_roll_up
    ScreenedIpAddress.exec_sql(star_subnets_query, min_count: min_count).values.flatten
  end

  def star_star_subnets
    weight = SiteSetting.min_ban_entries_for_roll_up
    ScreenedIpAddress.exec_sql(star_star_subnets_query, min_count: 10, roll_up_weight: weight).values.flatten
  end

  def roll_up
    # 1 - retrieve all subnets that needs roll up
    subnets = [star_subnets, star_star_subnets].flatten

    # 2 - log the call
    StaffActionLogger.new(current_user).log_roll_up(subnets) unless subnets.blank?

    subnets.each do |subnet|
      # 3 - create subnet if not already exists
      ScreenedIpAddress.new(ip_address: subnet).save unless ScreenedIpAddress.where(ip_address: subnet).first

      # 4 - update stats
      sql = <<-SQL
        UPDATE screened_ip_addresses
           SET match_count   = sum_match_count,
               created_at    = min_created_at,
               last_match_at = max_last_match_at
          FROM (
            SELECT SUM(match_count)   AS sum_match_count,
                   MIN(created_at)    AS min_created_at,
                   MAX(last_match_at) AS max_last_match_at
              FROM screened_ip_addresses
             WHERE action_type = #{ScreenedIpAddress.actions[:block]}
               AND family(ip_address) = 4
               AND ip_address << :ip_address
          ) s
         WHERE ip_address = :ip_address
      SQL

      ScreenedIpAddress.exec_sql(sql, ip_address: subnet)

      # 5 - remove old matches
      ScreenedIpAddress.where(action_type: ScreenedIpAddress.actions[:block])
                       .where("family(ip_address) = 4")
                       .where("ip_address << ?", subnet)
                       .delete_all
    end

    render json: success_json.merge!({ subnets: subnets })
  end

  private

    def allowed_params
      params.require(:ip_address)
      params.permit(:ip_address, :action_name)
    end

    def fetch_screened_ip_address
      @screened_ip_address = ScreenedIpAddress.find(params[:id])
    end

end
