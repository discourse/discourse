# frozen_string_literal: true

RSpec.describe Jobs::DsaNoticeReceipt do
  describe "#execute" do
    fab!(:admin)
    fab!(:group)

    let(:notice_params) do
      {
        submission_id: SecureRandom.uuid,
        content_url: "https://example.com/post?a=1&b=2",
        explanation:
          "This listing advertises counterfeit goods as authentic and its payment instructions appear intended to deceive buyers.",
        name: "Pat O'Brien",
        email: "alex@example.com",
        anonymous: false,
        declaration: true,
      }
    end

    let(:notice) { Dsa::Notice.create!(attributes: notice_params, group:) }
    let(:post_id) { notice.post.id }
    let(:job) { described_class.new }

    before do
      SiteSetting.disable_emails = "no"
      group.add(admin)
    end

    it "delivers a receipt once and marks it sent" do
      expect do
        job.execute(post_id:)
        job.execute(post_id:)
      end.to change { ActionMailer::Base.deliveries.size }.by(1)

      expect(Dsa::Notice.from_post(notice.post.reload)).to be_receipt_sent
    end

    it "sends nothing for an anonymous notice" do
      notice_params[:anonymous] = true
      notice_params[:name] = nil
      notice_params[:email] = nil
      expect { job.execute(post_id:) }.not_to change { ActionMailer::Base.deliveries.size }
    end

    it "leaves delivery pending after SMTP failure and can retry" do
      Email::Sender.any_instance.stubs(:send).raises(Net::SMTPServerBusy, "SMTP unavailable")
      expect { job.execute(post_id:) }.to raise_error(Net::SMTPServerBusy)
      expect(Dsa::Notice.from_post(notice.post.reload)).not_to be_receipt_sent
      Email::Sender.any_instance.unstub(:send)
      expect { job.execute(post_id:) }.to change { ActionMailer::Base.deliveries.size }.by(1)
    end

    it "leaves the receipt pending when delivery is suppressed" do
      SiteSetting.disable_emails = "yes"
      expect { job.execute(post_id:) }.not_to change { ActionMailer::Base.deliveries.size }
      expect(Dsa::Notice.from_post(notice.post.reload)).not_to be_receipt_sent
    end

    it "ignores a missing post" do
      expect { job.execute(post_id: -1) }.not_to change { ActionMailer::Base.deliveries.size }
    end
  end
end
