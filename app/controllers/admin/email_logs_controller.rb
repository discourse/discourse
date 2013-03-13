class Admin::EmailLogsController < Admin::AdminController

  def index
    @email_logs = EmailLog.limit(50).includes(:user).order('created_at desc').all

    render_serialized(@email_logs, EmailLogSerializer)
  end

  def test
    requires_parameter(:email_address)
    Jobs.enqueue(:test_email, to_address: params[:email_address])
    render nothing: true
  end

end
