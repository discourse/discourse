require_dependency 'screening_model'
require_dependency 'ip_addr'

# A ScreenedIpAddress record represents an IP address or subnet that is being watched,
# and possibly blocked from creating accounts.
class ScreenedIpAddress < ActiveRecord::Base

  include ScreeningModel

  default_action :block

  validates :ip_address, ip_address_format: true, presence: true

  def self.watch(ip_address, opts={})
    match_for_ip_address(ip_address) || create(opts.slice(:action_type).merge(ip_address: ip_address))
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
    find_by("'#{ip_address.to_s}' <<= ip_address")
  end

  def self.should_block?(ip_address)
    exists_for_ip_address_and_action?(ip_address, actions[:block])
  end

  def self.is_whitelisted?(ip_address)
    exists_for_ip_address_and_action?(ip_address, actions[:do_nothing])
  end

  def self.exists_for_ip_address_and_action?(ip_address, action_type, opts={})
    b = match_for_ip_address(ip_address)
    found = (!!b and b.action_type == action_type)
    b.record_match! if found and opts[:record_match] != false
    found
  end

  def self.block_login?(user, ip_address)
    return false if user.nil?
    return false if !user.admin?
    return false if ScreenedIpAddress.where(action_type: actions[:allow_admin]).count == 0
    return true if ip_address.nil?
    !exists_for_ip_address_and_action?(ip_address, actions[:allow_admin], record_match: false)
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
