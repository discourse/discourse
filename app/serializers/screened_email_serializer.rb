class ScreenedEmailSerializer < ApplicationSerializer
  attributes :email,
             :action,
             :match_count,
             :last_match_at,
             :created_at

  def action
    ScreenedEmail.actions.key(object.action_type).to_s
  end
end
