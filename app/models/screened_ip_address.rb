require_dependency 'screening_model'
require_dependency 'ip_addr'

# A ScreenedIpAddress record represents an IP address or subnet that is being watched,
# and possibly blocked from creating accounts.
class ScreenedIpAddress < ActiveRecord::Base

  include ScreeningModel

  default_action :block

  validates :ip_address, ip_address_format: true, presence: true
  after_validation :check_for_match

  def self.watch(ip_address, opts = {})
    match_for_ip_address(ip_address) || create(opts.slice(:action_type).merge(ip_address: ip_address))
  end

  def check_for_match
    unless self.errors[:ip_address].present?
      matched = self.class.match_for_ip_address(self.ip_address)
      if matched && matched.action_type == self.action_type
        self.errors.add(:ip_address, :ip_address_already_screened)
      end
    end
  end

  # In Rails 4.0.0, validators are run to handle invalid assignments to inet columns (as they should).
  # In Rails 4.0.1, an exception is raised before validation happens, so we need this hack for
  # inet/cidr columns:
  def ip_address=(val)
    if val.nil?
      self.errors.add(:ip_address, :invalid)
      return
    end

    if val.is_a?(IPAddr)
      write_attribute(:ip_address, val)
      return
    end

    v = IPAddr.handle_wildcards(val)

    if v.nil?
      self.errors.add(:ip_address, :invalid)
      return
    end

    write_attribute(:ip_address, v)

  # this gets even messier, Ruby 1.9.2 raised a different exception to Ruby 2.0.0
  # handle both exceptions
  rescue ArgumentError, IPAddr::InvalidAddressError
    self.errors.add(:ip_address, :invalid)
  end

  # Return a string with the ip address and mask in standard format. e.g., "127.0.0.0/8".
  def ip_address_with_mask
    ip_address.try(:to_cidr_s)
  end

  def self.match_for_ip_address(ip_address)
    # The <<= operator on inet columns means "is contained within or equal to".
    #
    # Read more about PostgreSQL's inet data type here:
    #
    #   http://www.postgresql.org/docs/9.1/static/datatype-net-types.html
    #   http://www.postgresql.org/docs/9.1/static/functions-net.html
    find_by("? <<= ip_address", ip_address.to_s)
  end

  def self.should_block?(ip_address)
    exists_for_ip_address_and_action?(ip_address, actions[:block])
  end

  def self.is_whitelisted?(ip_address)
    exists_for_ip_address_and_action?(ip_address, actions[:do_nothing])
  end

  def self.exists_for_ip_address_and_action?(ip_address, action_type, opts = {})
    b = match_for_ip_address(ip_address)
    found = (!!b && b.action_type == (action_type))
    b.record_match! if found && opts[:record_match] != (false)
    found
  end

  def self.block_admin_login?(user, ip_address)
    return false unless SiteSetting.use_admin_ip_whitelist
    return false if user.nil?
    return false if !user.admin?
    return false if ScreenedIpAddress.where(action_type: actions[:allow_admin]).count == 0
    return true if ip_address.nil?
    !exists_for_ip_address_and_action?(ip_address, actions[:allow_admin], record_match: false)
  end

  def self.star_subnets_query
    @star_subnets_query ||= <<~SQL
      SELECT network(inet(host(ip_address) || '/24'))::text AS ip_range
        FROM screened_ip_addresses
       WHERE action_type = #{ScreenedIpAddress.actions[:block]}
         AND family(ip_address) = 4
         AND masklen(ip_address) = 32
    GROUP BY ip_range
      HAVING COUNT(*) >= :min_count
    SQL
  end

  def self.star_star_subnets_query
    @star_star_subnets_query ||= <<~SQL
      WITH weighted_subnets AS (
        SELECT network(inet(host(ip_address) || '/16'))::text AS ip_range,
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

  def self.star_subnets
    min_count = SiteSetting.min_ban_entries_for_roll_up
    DB.query_single(star_subnets_query, min_count: min_count)
  end

  def self.star_star_subnets
    weight = SiteSetting.min_ban_entries_for_roll_up
    DB.query_single(star_star_subnets_query, min_count: 10, roll_up_weight: weight)
  end

  def self.roll_up(current_user = Discourse.system_user)
    subnets = [star_subnets, star_star_subnets].flatten

    StaffActionLogger.new(current_user).log_roll_up(subnets) unless subnets.blank?

    subnets.each do |subnet|
      ScreenedIpAddress.create(ip_address: subnet) unless ScreenedIpAddress.where("? <<= ip_address", subnet).exists?

      sql = <<~SQL
        UPDATE screened_ip_addresses
           SET match_count   = sum_match_count
             , created_at    = min_created_at
             , last_match_at = max_last_match_at
          FROM (
            SELECT SUM(match_count)   AS sum_match_count
                 , MIN(created_at)    AS min_created_at
                 , MAX(last_match_at) AS max_last_match_at
              FROM screened_ip_addresses
             WHERE action_type = #{ScreenedIpAddress.actions[:block]}
               AND family(ip_address) = 4
               AND ip_address << :ip_address
          ) s
         WHERE ip_address = :ip_address
      SQL

      DB.exec(sql, ip_address: subnet)

      ScreenedIpAddress.where(action_type: ScreenedIpAddress.actions[:block])
        .where("family(ip_address) = 4")
        .where("ip_address << ?", subnet)
        .delete_all
    end

    subnets
  end

end

# == Schema Information
#
# Table name: screened_ip_addresses
#
#  id            :integer          not null, primary key
#  ip_address    :inet             not null
#  action_type   :integer          not null
#  match_count   :integer          default(0), not null
#  last_match_at :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_screened_ip_addresses_on_ip_address     (ip_address) UNIQUE
#  index_screened_ip_addresses_on_last_match_at  (last_match_at)
#
