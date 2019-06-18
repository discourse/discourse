# frozen_string_literal: true

require "rails_helper"

describe TestMailer do

  describe "send_test" do

    it "works" do
      test_mailer = TestMailer.send_test('marcheline@adventuretime.ooo')

      expect(test_mailer.from).to eq([SiteSetting.notification_email])
      expect(test_mailer.to).to eq(['marcheline@adventuretime.ooo'])
      expect(test_mailer.subject).to be_present
      expect(test_mailer.body).to be_present
    end

  end

end
