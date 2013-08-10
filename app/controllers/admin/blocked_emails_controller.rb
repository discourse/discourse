class Admin::BlockedEmailsController < Admin::AdminController

  def index
    blocked_emails = BlockedEmail.limit(200).order('last_match_at desc').to_a
    render_serialized(blocked_emails, BlockedEmailSerializer)
  end

end
