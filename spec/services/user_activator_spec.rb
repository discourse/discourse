# frozen_string_literal: true

RSpec.describe UserActivator do
  fab!(:user)
  let!(:email_token) { Fabricate(:email_token, user: user) }

  describe "email_activator" do
    let(:activator) { EmailActivator.new(user, nil, nil, nil) }

    it "create email token and enqueues user email" do
      now = freeze_time
      activator.activate
      email_token = user.reload.email_tokens.last
      expect(email_token.created_at).to eq_time(now)
      job_args = Jobs::CriticalUserEmail.jobs.last["args"].first
      expect(job_args["user_id"]).to eq(user.id)
      expect(job_args["type"]).to eq("signup")
      expect(EmailToken.hash_token(job_args["email_token"])).to eq(email_token.token_hash)
    end
  end

  describe "login_activator" do
    let(:request) do
      ActionDispatch::TestRequest.create("rack.session" => { authenticated_with_oauth: true })
    end
    let(:session) { request.session }
    let(:cookies) { ActionDispatch::Cookies::CookieJar.build(request, {}) }
    let(:activator) { LoginActivator.new(user, request, session, cookies) }

    before { SiteSetting.send_welcome_message = true }

    it "passes authenticated_with_oauth from session to log_on_user" do
      activator.activate
      expect(user.user_auth_tokens.last.authenticated_with_oauth).to eq(true)
    end

    it "enqueues a welcome message and returns the active message" do
      message = activator.activate
      expect(Jobs::SendSystemMessage.jobs.last["args"].first["message_type"]).to eq("welcome_user")
      expect(message).to eq(I18n.t("login.active"))
    end
  end
end
