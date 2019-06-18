# frozen_string_literal: true

class ScreenedIpAddressSerializer < ApplicationSerializer
  attributes :id,
             :ip_address,
             :action_name,
             :match_count,
             :last_match_at,
             :created_at

  def action_name
    ScreenedIpAddress.actions.key(object.action_type).to_s
  end

  def ip_address
    object.ip_address_with_mask
  end

end
