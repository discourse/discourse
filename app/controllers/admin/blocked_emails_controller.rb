class Admin::BlockedEmailsController < Admin::AdminController

  def index
    blocked_emails = BlockedEmail.limit(50).order('created_at desc').to_a
    render_serialized(blocked_emails, BlockedEmailSerializer)
  end

end
