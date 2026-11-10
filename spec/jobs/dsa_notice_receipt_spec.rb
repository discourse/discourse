# frozen_string_literal: true

RSpec.describe Jobs::DsaNoticeReceipt do
  describe "#execute" do
    fab!(:admin)
    fab!(:group)

    let(:notice_params) do
      {
        content_url: "https://example.com/post?a=1&b=2",
        explanation:
          "This listing advertises counterfeit goods as authentic and its payment instructions appear intended to deceive buyers.",
        name: "Pat O'Brien",
        email: "alex@example.com",
      }
    end

    let(:notice) { Dsa::Notice.create_with_post!(attributes: notice_params, group:) }
    let(:notice_id) { notice.id }
    let(:job) { described_class.new }

    before do
      SiteSetting.disable_emails = "no"
      group.add(admin)
    end

    it "delivers a receipt once and marks it sent" do
      expect do
        job.execute(notice_id:)
        job.execute(notice_id:)
      end.to change { ActionMailer::Base.deliveries.size }.by(1)

      expect(notice.reload).to be_receipt_sent
    end

    it "leaves delivery pending after SMTP failure and can retry" do
      Email::Sender.any_instance.stubs(:send).raises(Net::SMTPServerBusy, "SMTP unavailable")
      expect { job.execute(notice_id:) }.to raise_error(Net::SMTPServerBusy)
      expect(notice.reload).not_to be_receipt_sent
      Email::Sender.any_instance.unstub(:send)
      expect { job.execute(notice_id:) }.to change { ActionMailer::Base.deliveries.size }.by(1)
    end

    it "leaves the receipt pending when delivery is suppressed" do
      SiteSetting.disable_emails = "yes"
      expect { job.execute(notice_id:) }.not_to change { ActionMailer::Base.deliveries.size }
      expect(notice.reload).not_to be_receipt_sent
    end

    it "ignores a missing notice" do
      expect { job.execute(notice_id: -1) }.not_to change { ActionMailer::Base.deliveries.size }
    end
  end
end
