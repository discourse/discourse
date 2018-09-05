require "rails_helper"

describe ApplicationMailer do

  describe "secondary_delivery" do
    before do
      SiteSetting.smtp_address = 'xyz.com'
      SiteSetting.smtp_port = 123
    end

    it "sends email with default smtp settings" do
      test_mailer = TestMailer.send_test('marcheline@adventuretime.ooo')
      expect(test_mailer.delivery_method.settings).to eq({})
    end

    it "sends email with secondary smtp settings" do
      SiteSetting.enable_secondary_smtp = true
      test_mailer = TestMailer.send_test('marcheline@adventuretime.ooo')
      expect(test_mailer.delivery_method.settings).to eq(address: "xyz.com", port: "123")
    end
  end

end
