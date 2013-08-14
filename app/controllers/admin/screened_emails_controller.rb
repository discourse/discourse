class Admin::ScreenedEmailsController < Admin::AdminController

  def index
    screened_emails = ScreenedEmail.limit(200).order('last_match_at desc').to_a
    render_serialized(screened_emails, ScreenedEmailSerializer)
  end

end
