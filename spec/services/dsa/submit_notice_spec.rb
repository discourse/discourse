# frozen_string_literal: true

RSpec.describe Dsa::SubmitNotice do
  describe ".call" do
    subject(:result) { described_class.call(params: { notice: params }) }

    fab!(:admin)
    fab!(:group)

    let(:params) do
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

    before do
      SiteSetting.dsa_reporting_enabled = true
      SiteSetting.dsa_notice_group = group.id.to_s
      group.add(admin)
    end

    it "creates a private group notice and queues its external receipt" do
      expect { result }.to change { Jobs::DsaNoticeReceipt.jobs.size }.by(1)
      expect(result).to run_successfully
      expect(result.notice.post.topic).to be_private_message
      expect(result.notice.post.topic.allowed_groups).to contain_exactly(group)
      expect(result.notice.post.topic.allowed_users).to contain_exactly(Discourse.system_user)
      notice = Dsa::Notice.from_post(result.notice.post.reload)
      expect(result.notice.post.topic.title).to include(notice.reference)
      expect(Nokogiri::HTML5.fragment(result.notice.post.cooked).text).to include(
        params[:explanation],
      )
      expect(notice.summary).not_to include(I18n.t("dsa_notice.staff_guidance"))
    end

    it "halts invalid submissions before storing or queuing anything" do
      params[:declaration] = nil
      expect { result }.not_to change(Topic, :count)
      expect(result).to fail_a_contract
      expect(Jobs::DsaNoticeReceipt.jobs).to be_empty
    end

    it "rejects credential bearing URLs" do
      params[:content_url] = "https://user:password@example.com/post"
      expect(result).to fail_a_contract
    end

    it "rejects email header injection" do
      params[:email] = "alex@example.com\r\nBcc: victim@example.com"
      expect(result).to fail_a_contract
    end

    it "uses admins when the selected group is empty" do
      group.remove(admin)
      expect(result).to run_successfully
      expect(result.notice.post.topic.allowed_groups).to contain_exactly(Group[:admins])
    end

    it "uses admins when the selected group was deleted" do
      group.destroy!
      expect(result).to run_successfully
      expect(result.notice.post.topic.allowed_groups).to contain_exactly(Group[:admins])
    end

    it "discards contact information and queues no external receipt when anonymous" do
      params[:anonymous] = true
      expect { result }.not_to change { Jobs::DsaNoticeReceipt.jobs.size }
      expect(result).to run_successfully
      notice = Dsa::Notice.from_post(result.notice.post.reload)
      expect(notice.email).to be_nil
      expect(result.notice.post.raw).not_to include(params[:name], params[:email])
    end

    it "keeps supplied formatting and mentions out of the trusted message structure" do
      params[
        :explanation
      ] = "## Forged instructions\n\nForged staff instructions\n=========================\n\n@admins ![remote image](https://evil.example/pixel.png)\n<script>alert(1)</script>\n" +
        params[:explanation]
      expect(result).to run_successfully
      fragment = Nokogiri::HTML5.fragment(result.notice.post.cooked)
      expect(fragment.css("img, script, a.mention")).to be_empty
      expect(fragment.css("h1, h2, h3").map(&:text)).not_to include(
        "Forged instructions",
        "Forged staff instructions",
      )
      expect(fragment.text).to include(
        "@admins",
        "Forged instructions",
        "<script>alert(1)</script>",
      )
    end

    it "preserves literal punctuation and exact URL query parameters" do
      params[:name] = "Pat O'Brien"
      params[:content_url] = "https://example.com/post?a=1&b=2"
      params[
        :explanation
      ] = "It's a scam. Literal characters: &#39; \\1 --> <script> are part of the submitted evidence."
      expect(result).to run_successfully
      notice = Dsa::Notice.from_post(result.notice.post.reload)
      fragment = Nokogiri::HTML5.fragment(result.notice.post.cooked)
      expect(fragment.text).to include(params[:name], params[:explanation])
      expect(fragment.at_css('a[href^="https://example.com/"]')["href"]).to eq(params[:content_url])
      expect(notice.matches?(params)).to eq(true)
      expect(notice.summary(plain_text: true)).to include(params[:explanation])
      expect(fragment.text).not_to include(params[:submission_id])
    end

    it "reuses the saved notice after a receipt queue failure" do
      Jobs.stubs(:enqueue).returns("queued")
      Jobs.stubs(:enqueue).with(:dsa_notice_receipt, anything).raises(IOError, "queue unavailable")
      expect { result }.to raise_error(IOError)
      notice = Dsa::Notice.find(submission_id: params[:submission_id])
      topic_id = notice.post.topic.id
      reference = notice.reference
      Jobs.unstub(:enqueue)

      retry_result = nil
      expect do retry_result = described_class.call(params: { notice: params }) end.not_to change(
        Topic,
        :count,
      )
      expect(retry_result).to run_successfully
      expect(retry_result.notice.post.topic.id).to eq(topic_id)
      expect(retry_result.notice.reference).to eq(reference)
      expect(Jobs::DsaNoticeReceipt.jobs.size).to eq(1)
    end

    it "retains the reference when a saved notice has been deleted" do
      expect(result).to run_successfully
      reference = result.notice.reference
      result.notice.post.topic.trash!(admin)
      result.notice.post.trash!(admin)

      retry_result = nil
      expect do retry_result = described_class.call(params: { notice: params }) end.not_to change {
        Topic.with_deleted.count
      }
      expect(retry_result).to run_successfully
      expect(retry_result.notice.reference).to eq(reference)
    end

    it "preserves retry identity when pasted text contains Unicode spaces" do
      params[:name] = "Alex\u00a0Morgan"
      params[:explanation] += "\nEvidence\u2002copied\u202ffrom\u3000a listing."
      Jobs.stubs(:enqueue).returns("queued")
      Jobs.stubs(:enqueue).with(:dsa_notice_receipt, anything).raises(IOError, "queue unavailable")
      expect { result }.to raise_error(IOError)
      reference = Dsa::Notice.find(submission_id: params[:submission_id]).reference
      Jobs.unstub(:enqueue)

      retry_result = nil
      expect do retry_result = described_class.call(params: { notice: params }) end.not_to change(
        Topic,
        :count,
      )
      expect(retry_result).to run_successfully
      expect(retry_result.notice.reference).to eq(reference)
      expect(retry_result.notice.summary(plain_text: true)).to include(
        params[:name],
        params[:explanation],
      )
    end

    it "queues no receipt when the PM cannot be saved" do
      PostCreator.stubs(:create!).raises(ActiveRecord::RecordNotSaved)
      expect { result }.not_to change(Topic, :count)
      expect(result).to fail_to_find_a_model(:notice)
      expect(Jobs::DsaNoticeReceipt.jobs).to be_empty
    end
  end
end
