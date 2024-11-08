# frozen_string_literal: true

require "screening_model"

# A ScreenedIpAddress record represents an IP address or subnet that is being watched,
# and possibly blocked from creating accounts.
class ScreenedIpAddress < ActiveRecord::Base
  include ScreeningModel

  default_action :block

  validates :ip_address, ip_address_format: true, presence: true
  after_validation :check_for_match, if: :will_save_change_to_ip_address?

  ROLLED_UP_BLOCKS = [
    # IPv4
    [4, 32, 24],
    # IPv6
    [6, (65..128).to_a, 64],
    [6, 64, 60],
    [6, 60, 56],
    [6, 56, 52],
    [6, 52, 48],
  ].freeze

  def self.watch(ip_address, opts = {})
    match_for_ip_address(ip_address) ||
      create(opts.slice(:action_type).merge(ip_address: ip_address))
  end

  def check_for_match
    if self.errors[:ip_address].blank?
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
    ip_address = IPAddr === ip_address ? ip_address.to_cidr_s : ip_address.to_s
    order("masklen(ip_address) DESC").find_by("? <<= ip_address", ip_address)
  end

  def self.should_block?(ip_address)
    exists_for_ip_address_and_action?(ip_address, actions[:block])
  end

  def self.is_allowed?(ip_address)
    exists_for_ip_address_and_action?(ip_address, actions[:do_nothing])
  end

  def self.exists_for_ip_address_and_action?(ip_address, action_type, opts = {})
    b = match_for_ip_address(ip_address)
    found = !!b && b.action_type == action_type
    b.record_match! if found && opts[:record_match] != false
    found
  end

  def self.block_admin_login?(user, ip_address)
    return false unless SiteSetting.use_admin_ip_allowlist
    return false if user.nil?
    return false if !user.admin?
    return false if ScreenedIpAddress.where(action_type: actions[:allow_admin]).count == 0
    return true if ip_address.nil?
    !exists_for_ip_address_and_action?(ip_address, actions[:allow_admin], record_match: false)
  end

  def self.subnets(family, from_masklen, to_masklen)
    sql = <<~SQL
      WITH ips_and_subnets AS (
        SELECT ip_address,
               network(inet(host(ip_address) || '/' || :to_masklen))::text subnet
        FROM screened_ip_addresses
        WHERE family(ip_address) = :family AND
              masklen(ip_address) IN (:from_masklen) AND
              action_type = :blocked
      )
      SELECT subnet
      FROM ips_and_subnets
      GROUP BY subnet
      HAVING COUNT(*) >= :min_ban_entries_for_roll_up
    SQL

    DB.query_single(
      sql,
      family: family,
      from_masklen: from_masklen,
      to_masklen: to_masklen,
      blocked: ScreenedIpAddress.actions[:block],
      min_ban_entries_for_roll_up: SiteSetting.min_ban_entries_for_roll_up,
    )
  end

  def self.roll_up(current_user = Discourse.system_user)
    ROLLED_UP_BLOCKS.each do |family, from_masklen, to_masklen|
      ScreenedIpAddress
        .subnets(family, from_masklen, to_masklen)
        .map do |subnet|
          next if ScreenedIpAddress.where("? <<= ip_address", subnet).exists?

          old_ips =
            ScreenedIpAddress
              .where(action_type: ScreenedIpAddress.actions[:block])
              .where("ip_address << ?", subnet)
              .where("family(ip_address) = ?", family)
              .where("masklen(ip_address) IN (?)", from_masklen)

          sum_match_count, max_last_match_at, min_created_at =
            old_ips.pick("SUM(match_count), MAX(last_match_at), MIN(created_at)")

          ScreenedIpAddress.create!(
            ip_address: subnet,
            match_count: sum_match_count,
            last_match_at: max_last_match_at,
            created_at: min_created_at,
          )

          StaffActionLogger.new(current_user).log_roll_up(subnet, old_ips.map(&:ip_address))
          old_ips.delete_all
        end
    end
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
