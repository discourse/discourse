require "spec_helper"

describe VersionMailer do
  subject { VersionMailer.send_notice }

  context 'contact_email is blank' do
    before { SiteSetting.stubs(:contact_email).returns('') }
    its(:to) { should be_blank }
  end

  context 'contact_email is set' do
    before { SiteSetting.stubs(:contact_email).returns('me@example.com') }
    its(:to) { should == ['me@example.com'] }
    its(:subject) { should be_present }
    its(:from) { should == [SiteSetting.notification_email] }
    its(:body) { should be_present }
  end
end
