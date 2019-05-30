# frozen_string_literal: true

class ScreenedUrlSerializer < ApplicationSerializer
  attributes :url,
             :domain,
             :action,
             :match_count,
             :last_match_at,
             :created_at,
             :ip_address

  def action
    ScreenedUrl.actions.key(object.action_type).to_s
  end

  def ip_address
    object.ip_address.try(:to_s)
  end

end
