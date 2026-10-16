# frozen_string_literal: true

RSpec.describe Jobs::DsaNoticeReceipt do
  describe "#execute" do
    fab!(:admin)
    fab!(:group)

    let(:notice_params) do
      {
        submission_id: SecureRandom.uuid,
        content_url: "#{Discourse.base_url}/t/reported/123",
        explanation:
          "This listing advertises counterfeit goods as authentic and its payment instructions appear intended to deceive buyers.",
        name: "Alex Morgan",
        email: "alex@example.com",
        anonymous: false,
        declaration: true,
      }
    end

    let(:topic) { Dsa::SubmitNotice.call(params: notice_params).topic }
    let(:job) { described_class.new }

    before do
      SiteSetting.dsa_reporting_enabled = true
      SiteSetting.dsa_notice_group = group.id.to_s
      SiteSetting.disable_emails = "no"
      group.add(admin)
    end

    it "delivers the original summary once without later staff replies or PM reply instructions" do
      PostCreator.create!(admin, topic_id: topic.id, raw: "Confidential staff investigation notes")
      expect do
        job.execute(topic_id: topic.id)
        job.execute(topic_id: topic.id)
      end.to change { ActionMailer::Base.deliveries.size }.by(1)

      message = ActionMailer::Base.deliveries.last
      expect(message.to).to eq([notice_params[:email]])
      expect(message.subject).to include(topic.custom_fields["dsa_notice"]["reference"])
      expect(message.text_part.decoded).to include(notice_params[:explanation])
      expect(message.text_part.decoded).not_to include(
        "Confidential staff investigation notes",
        "For the reviewing team",
      )
      expect(message.html_part.decoded).to include(notice_params[:explanation])
      expect(message["X-Discourse-Reply-Key"]).to be_nil
      expect(topic.reload.custom_fields["dsa_notice_receipt_sent"]).to eq("t")
    end

    it "sends nothing for an anonymous notice" do
      notice_params[:anonymous] = true
      expect { job.execute(topic_id: topic.id) }.not_to change {
        ActionMailer::Base.deliveries.size
      }
    end

    it "leaves delivery pending after SMTP failure and can retry" do
      DsaNoticeMailer.stubs(:receipt).raises(Net::SMTPServerBusy, "SMTP unavailable")
      expect { job.execute(topic_id: topic.id) }.to raise_error(Net::SMTPServerBusy)
      expect(topic.reload.custom_fields["dsa_notice_receipt_sent"]).to be_nil
      DsaNoticeMailer.unstub(:receipt)
      expect { job.execute(topic_id: topic.id) }.to change {
        ActionMailer::Base.deliveries.size
      }.by(1)
    end

    it "does not mark suppressed email as sent" do
      SiteSetting.disable_emails = "yes"
      expect { job.execute(topic_id: topic.id) }.not_to change {
        ActionMailer::Base.deliveries.size
      }
      expect(topic.reload.custom_fields["dsa_notice_receipt_sent"]).to be_nil
    end

    it "ignores a missing topic" do
      expect { job.execute(topic_id: -1) }.not_to change { ActionMailer::Base.deliveries.size }
    end
  end
end
