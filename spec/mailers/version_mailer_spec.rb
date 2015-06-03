require "spec_helper"

describe VersionMailer do
  subject { VersionMailer.send_notice }

  context 'contact_email is blank' do
    before { SiteSetting.contact_email = '' }

    it "doesn't send the email" do
      expect(subject.to).to be_blank
    end
  end

  context 'contact_email is set' do
    before { SiteSetting.contact_email = 'me@example.com' }

    it "works" do
      expect(subject.to).to eq(['me@example.com'])
      expect(subject.subject).to be_present
      expect(subject.from).to eq([SiteSetting.notification_email])
      expect(subject.body).to be_present
    end

  end
end
