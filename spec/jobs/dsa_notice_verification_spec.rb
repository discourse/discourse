# frozen_string_literal: true

RSpec.describe Jobs::DsaNoticeVerification do
  describe "#execute" do
    let(:email) { "alex@example.com" }
    let(:token) { Dsa::NoticeVerification.create(email) }
    let(:job) { described_class.new }

    before { SiteSetting.disable_emails = "no" }

    it "emails the reporter without consuming the verification" do
      expect { job.execute(token:) }.to change { ActionMailer::Base.deliveries.size }.by(1)

      expect(ActionMailer::Base.deliveries.last.to).to eq([email])
      expect(Dsa::NoticeVerification.find(token)).to include(email:)
    end

    it "sends nothing after the email has been verified" do
      code = Dsa::NoticeVerification.find(token)[:code]
      Dsa::NoticeVerification.verify(token:, email:, code:)

      expect { job.execute(token:) }.not_to change { ActionMailer::Base.deliveries.size }
    end

    it "sends nothing when the pending submission is unavailable" do
      expect { job.execute(token: "a" * 64) }.not_to change { ActionMailer::Base.deliveries.size }
    end
  end
end
