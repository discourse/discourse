# frozen_string_literal: true

RSpec.describe Jobs::SendSessionConfirmationCode do
  fab!(:user)

  before do
    SiteSetting.enable_local_logins = true
    SiteSetting.enable_local_logins_via_email = true
  end

  it "raises an error without a to_address" do
    expect { described_class.new.execute(code: "123456") }.to raise_error(
      Discourse::InvalidParameters,
      /to_address/,
    )
  end

  it "raises an error without a code" do
    expect { described_class.new.execute(to_address: user.email) }.to raise_error(
      Discourse::InvalidParameters,
      /code/,
    )
  end

  it "does not send an email when local logins, email logins, or SSO disallow it" do
    SiteSetting.enable_local_logins_via_email = false
    described_class.new.execute(user_id: user.id, to_address: user.email, code: "123456")
    expect(ActionMailer::Base.deliveries).to be_empty

    SiteSetting.enable_local_logins_via_email = true
    SiteSetting.enable_local_logins = false
    described_class.new.execute(user_id: user.id, to_address: user.email, code: "123456")
    expect(ActionMailer::Base.deliveries).to be_empty

    SiteSetting.enable_local_logins = true
    SiteSetting.discourse_connect_url = "https://example.com/sso"
    SiteSetting.discourse_connect_secret = "x" * 10
    SiteSetting.enable_discourse_connect = true
    described_class.new.execute(user_id: user.id, to_address: user.email, code: "123456")
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "sends an email using the session_confirmation_code_mailer template" do
    described_class.new.execute(user_id: user.id, to_address: user.email, code: "123456")

    email = ActionMailer::Base.deliveries.last
    expect(email.to).to contain_exactly(user.email)
    expect(email.subject).to eq(
      I18n.t("session_confirmation_code_mailer.subject_template", code: "123456"),
    )
    expect(email.body.to_s).to include("123456", "confirm your identity")
  end
end
