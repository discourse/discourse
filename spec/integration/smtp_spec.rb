# frozen_string_literal: true

RSpec.describe "SMTP Settings Integration" do
  before do
    @original_action_mailer_smtp_settings = ActionMailer::Base.smtp_settings
    @original_action_mailer_delivery_method = ActionMailer::Base.delivery_method
    ActionMailer::Base.delivery_method = :smtp
  end

  after do
    ActionMailer::Base.smtp_settings = @original_action_mailer_smtp_settings
    ActionMailer::Base.delivery_method = @original_action_mailer_delivery_method
  end

  it "should send out the email successfully using the SMTP settings" do
    global_setting :smtp_address, "some.host"
    global_setting :smtp_port, 12_345

    ActionMailer::Base.smtp_settings = GlobalSetting.smtp_settings

    message = TestMailer.send_test("some_email")

    expect do Email::Sender.new(message, :test_message).send end.to raise_error(
      StandardError,
      /some.host/,
    )
  end
end
