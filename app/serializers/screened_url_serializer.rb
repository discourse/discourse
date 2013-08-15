class ScreenedUrlSerializer < ApplicationSerializer
  attributes :url,
             :domain,
             :action,
             :match_count,
             :last_match_at,
             :created_at

  def action
    ScreenedUrl.actions.key(object.action_type).to_s
  end
end
