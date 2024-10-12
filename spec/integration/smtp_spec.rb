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

  it "should attempt to send out an email without raising any SMTP argument errors" do
    global_setting :smtp_address, "1.2.3.4"
    global_setting :smtp_port, 12_345
    global_setting :smtp_open_timeout, 0.00001

    ActionMailer::Base.smtp_settings = GlobalSetting.smtp_settings

    message = TestMailer.send_test("some_email")

    expect do Email::Sender.new(message, :test_message).send end.to raise_error(Net::OpenTimeout)
  end
end
