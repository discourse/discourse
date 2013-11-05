class GroupedScreenedUrlSerializer < ApplicationSerializer
  attributes :domain,
             :action,
             :match_count,
             :last_match_at,
             :created_at

  def action
    'do_nothing'
  end
end
