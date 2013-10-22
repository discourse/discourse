class ScreenedIpAddressSerializer < ApplicationSerializer
  attributes :id,
             :ip_address,
             :action,
             :match_count,
             :last_match_at,
             :created_at

  def action
    ScreenedIpAddress.actions.key(object.action_type).to_s
  end

end
