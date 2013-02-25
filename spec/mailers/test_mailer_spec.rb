require "spec_helper"

describe TestMailer do

  describe "send_test" do
    subject { TestMailer.send_test('marcheline@adventuretime.ooo') }

    its(:to) { should == ['marcheline@adventuretime.ooo'] }
    its(:subject) { should be_present }
    its(:body) { should be_present }
    its(:from) { should == [SiteSetting.notification_email] }
  end


end
