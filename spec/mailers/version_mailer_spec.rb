require "spec_helper"

describe VersionMailer do
  subject { VersionMailer.send_notice }

  context 'contact_email is blank' do
    before { SiteSetting.stubs(:contact_email).returns('') }

    it "doesn't send the email" do
      subject.to.should be_blank
    end
  end

  context 'contact_email is set' do
    before { SiteSetting.stubs(:contact_email).returns('me@example.com') }

    it "works" do
      subject.to.should == ['me@example.com']
      subject.subject.should be_present
      subject.from.should == [SiteSetting.notification_email]
      subject.body.should be_present
    end

  end
end
