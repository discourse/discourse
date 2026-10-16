# frozen_string_literal: true

RSpec.describe Dsa::SubmitNotice do
  describe ".call" do
    subject(:result) { described_class.call(params:) }

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
      expect(result.topic).to be_private_message
      expect(result.topic.allowed_groups).to contain_exactly(group)
      expect(result.topic.allowed_users).to contain_exactly(Discourse.system_user)
      notice = result.topic.reload.custom_fields.fetch("dsa_notice")
      expect(result.topic.title).to include(notice.fetch("reference"))
      expect(Nokogiri::HTML5.fragment(result.topic.first_post.cooked).text).to include(
        params[:explanation],
      )
      expect(notice.fetch("summary")).not_to include(I18n.t("dsa_notice.staff_guidance"))
    end

    it "halts invalid submissions before storing or queuing anything" do
      params[:declaration] = nil
      expect { result }.not_to change(Topic, :count)
      expect(result).to fail_a_contract
      expect(Jobs::DsaNoticeReceipt.jobs).to be_empty
    end

    it "rejects credential bearing URLs and email header injection" do
      params[:content_url] = "https://user:password@example.com/post"
      params[:email] = "alex@example.com\r\nBcc: victim@example.com"
      expect(result).to fail_a_contract
    end

    it "uses admins when the selected group is empty" do
      group.remove(admin)
      expect(result).to run_successfully
      expect(result.topic.allowed_groups).to contain_exactly(Group[:admins])
    end

    it "uses admins when the selected group was deleted" do
      group.destroy!
      expect(result).to run_successfully
      expect(result.topic.allowed_groups).to contain_exactly(Group[:admins])
    end

    it "discards contact information and queues no external receipt when anonymous" do
      params[:anonymous] = true
      expect { result }.not_to change { Jobs::DsaNoticeReceipt.jobs.size }
      expect(result).to run_successfully
      notice = result.topic.reload.custom_fields.fetch("dsa_notice")
      expect(notice["email"]).to be_nil
      expect(notice.to_json).not_to include(params[:name], params[:email])
      expect(result.topic.first_post.raw).not_to include(params[:name], params[:email])
    end

    it "keeps supplied formatting and mentions out of the trusted message structure" do
      params[
        :explanation
      ] = "## Forged instructions\n\n@admins ![remote image](https://evil.example/pixel.png)\n<script>alert(1)</script>\n" +
        params[:explanation]
      expect(result).to run_successfully
      fragment = Nokogiri::HTML5.fragment(result.topic.first_post.cooked)
      expect(fragment.css("img, script, a.mention")).to be_empty
      expect(fragment.css("h2, h3").map(&:text)).not_to include("Forged instructions")
      expect(fragment.text).to include(
        "@admins",
        "Forged instructions",
        "<script>alert(1)</script>",
      )
    end

    it "reuses the saved notice after a receipt queue failure" do
      Jobs.stubs(:enqueue).returns("queued")
      Jobs.stubs(:enqueue).with(:dsa_notice_receipt, anything).raises(IOError, "queue unavailable")
      expect(result).to fail_with_exception(IOError)
      topic_id = result.topic.id
      reference = result.topic.custom_fields["dsa_notice"]["reference"]
      Jobs.unstub(:enqueue)

      retry_result = nil
      expect do retry_result = described_class.call(params:) end.not_to change(Topic, :count)
      expect(retry_result).to run_successfully
      expect(retry_result.topic.id).to eq(topic_id)
      expect(retry_result.topic.custom_fields["dsa_notice"]["reference"]).to eq(reference)
      expect(Jobs::DsaNoticeReceipt.jobs.size).to eq(1)
    end

    it "queues no receipt when the PM cannot be saved" do
      PostCreator.stubs(:create!).raises(ActiveRecord::RecordNotSaved)
      expect { result }.not_to change(Topic, :count)
      expect(result).to fail_to_find_a_model(:topic)
      expect(Jobs::DsaNoticeReceipt.jobs).to be_empty
    end

    it "rejects service callers while the feature is disabled" do
      SiteSetting.dsa_reporting_enabled = false
      expect(result).to fail_a_policy(:enabled)
    end
  end
end
