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

    let(:topic) { Dsa::SubmitNotice.call(params: { notice: notice_params }).notice.post.topic }
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
        job.execute(post_id: topic.first_post.id)
        job.execute(post_id: topic.first_post.id)
      end.to change { ActionMailer::Base.deliveries.size }.by(1)

      message = ActionMailer::Base.deliveries.last
      expect(message.to).to eq([notice_params[:email]])
      expect(message.subject).to include(Dsa::Notice.from_post(topic.first_post).reference)
      expect(message.text_part.decoded).to include(notice_params[:explanation])
      expect(message.text_part.decoded).not_to include(
        "Confidential staff investigation notes",
        "For the reviewing team",
      )
      fragment = Nokogiri::HTML5.fragment(message.html_part.decoded)
      expect(fragment.text).to include(notice_params[:explanation], notice_params[:name])
      expect(fragment.at_css('a[href^="https://example.com/"]')["href"]).to eq(
        notice_params[:content_url],
      )
      expect(message.html_part.decoded).not_to include("<!-- dsa-notice:", "submission_id")
      expect(message["X-Discourse-Reply-Key"]).to be_nil
      expect(Dsa::Notice.from_post(topic.first_post.reload)).to be_receipt_sent
    end

    it "sends nothing for an anonymous notice" do
      notice_params[:anonymous] = true
      expect { job.execute(post_id: topic.first_post.id) }.not_to change {
        ActionMailer::Base.deliveries.size
      }
    end

    it "leaves delivery pending after SMTP failure and can retry" do
      DsaNoticeMailer.stubs(:receipt).raises(Net::SMTPServerBusy, "SMTP unavailable")
      expect { job.execute(post_id: topic.first_post.id) }.to raise_error(Net::SMTPServerBusy)
      expect(Dsa::Notice.from_post(topic.first_post.reload)).not_to be_receipt_sent
      DsaNoticeMailer.unstub(:receipt)
      expect { job.execute(post_id: topic.first_post.id) }.to change {
        ActionMailer::Base.deliveries.size
      }.by(1)
    end

    %w[yes non-staff].each do |suppression|
      it "skips delivery when email suppression is #{suppression}" do
        SiteSetting.disable_emails = suppression
        post_id = topic.first_post.id
        expect do job.execute(post_id:) end.not_to change {
          [ActionMailer::Base.deliveries.size, described_class.jobs.size]
        }
        expect(Dsa::Notice.from_post(topic.first_post.reload)).not_to be_receipt_sent

        SiteSetting.disable_emails = "no"
        expect { job.execute(post_id: topic.first_post.id) }.to change {
          ActionMailer::Base.deliveries.size
        }.by(1)
        expect(Dsa::Notice.from_post(topic.first_post.reload)).to be_receipt_sent
      end
    end

    it "ignores a missing post" do
      expect { job.execute(post_id: -1) }.not_to change { ActionMailer::Base.deliveries.size }
    end
  end
end
