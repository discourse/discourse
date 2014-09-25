require "spec_helper"

describe TestMailer do

  describe "send_test" do

    it "works" do
      test_mailer = TestMailer.send_test('marcheline@adventuretime.ooo')

      test_mailer.from.should == [SiteSetting.notification_email]
      test_mailer.to.should == ['marcheline@adventuretime.ooo']
      test_mailer.subject.should be_present
      test_mailer.body.should be_present
    end

  end

end
