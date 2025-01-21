# frozen_string_literal: true

class Admin::ScreenedEmailsController < Admin::StaffController
  before_action :ensure_can_see_emails

  def index
    screened_emails = ScreenedEmail.limit(200).order("last_match_at desc").to_a
    render_serialized(screened_emails, ScreenedEmailSerializer)
  end

  def destroy
    screen = ScreenedEmail.find(params[:id].to_i)
    screen.destroy!
    render json: success_json
  end

  def ensure_can_see_emails
    guardian.ensure_can_see_emails!
  end
end
