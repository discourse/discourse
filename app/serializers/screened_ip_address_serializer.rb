class ScreenedIpAddressSerializer < ApplicationSerializer
  attributes :ip_address,
             :action,
             :match_count,
             :last_match_at,
             :created_at

  def action
    ScreenedIpAddress.actions.key(object.action_type).to_s
  end

end
