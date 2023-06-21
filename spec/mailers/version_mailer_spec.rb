# frozen_string_literal: true

RSpec.describe VersionMailer do
  subject(:mail) { VersionMailer.send_notice }

  context "when contact_email is blank" do
    before { SiteSetting.contact_email = "" }

    it "doesn't send the email" do
      expect(mail.to).to be_blank
    end
  end

  context "when contact_email is set" do
    before { SiteSetting.contact_email = "me@example.com" }

    it "works" do
      expect(mail.to).to eq(["me@example.com"])
      expect(mail.subject).to be_present
      expect(mail.from).to eq([SiteSetting.notification_email])
      expect(mail.body).to be_present
    end
  end
end
