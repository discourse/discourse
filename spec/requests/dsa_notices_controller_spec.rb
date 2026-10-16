# frozen_string_literal: true

RSpec.describe DsaNoticesController do
  fab!(:group)

  before do
    SiteSetting.dsa_reporting_enabled = true
    SiteSetting.dsa_notice_group = group.id.to_s
  end

  describe "#index" do
    it "serves the form and site title without login on a private site" do
      SiteSetting.login_required = true
      get "/dsa/illegal-content"
      expect(response.status).to eq(200)
      get "/dsa/illegal-content.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq("site_title" => SiteSetting.title)
    end

    it "returns not found when disabled" do
      SiteSetting.dsa_reporting_enabled = false
      get "/dsa/illegal-content.json"
      expect(response.status).to eq(404)
    end
  end

  describe "#create" do
    let(:notice) do
      {
        submission_id: SecureRandom.uuid,
        content_url: "#{Discourse.base_url}/t/reported-content/123/4",
        explanation:
          "This listing advertises counterfeit goods as authentic and its payment instructions appear intended to deceive buyers.",
        name: "Alex Morgan",
        email: "alex@example.invalid",
        anonymous: false,
        declaration: true,
      }
    end

    it "accepts a notice without login and returns its reference" do
      SiteSetting.login_required = true
      post "/dsa/illegal-content.json", params: { notice: }
      expect(response.status).to eq(201)
      expect(response.parsed_body["reference"]).to start_with("DSA-")
      expect(response.parsed_body["contact"]).to eq(true)
    end

    it "ignores supplied contact details on anonymous submissions" do
      post "/dsa/illegal-content.json", params: { notice: notice.merge(anonymous: true) }
      expect(response.status).to eq(201)
      expect(response.parsed_body["contact"]).to eq(false)
      reference = response.parsed_body["reference"]
      sign_in(Fabricate(:admin))
      topic = Topic.find_by!(title: I18n.t("dsa_notice.subject", reference:))
      get "/t/#{topic.id}.json"
      expect(response.status).to eq(200)
      cooked = response.parsed_body.dig("post_stream", "posts", 0, "cooked")
      expect(cooked).not_to include(notice[:name], notice[:email])
    end

    it "returns the original reference for a retry of the same submission" do
      post "/dsa/illegal-content.json", params: { notice: }
      expect(response.status).to eq(201)
      reference = response.parsed_body["reference"]
      expect do post "/dsa/illegal-content.json", params: { notice: } end.not_to change(
        Topic,
        :count,
      )
      expect(response.status).to eq(201)
      expect(response.parsed_body["reference"]).to eq(reference)
    end

    it "rejects invalid content, declaration and contact details with errors" do
      [
        { content_url: "javascript:alert(1)" },
        { explanation: "too short" },
        { explanation: "x" * 20_001 },
        { declaration: false },
        { name: " " },
        { email: "invalid" },
        { email: "victim@example.invalid\r\nBcc: other@example.invalid" },
        { submission_id: "invalid" },
      ].each do |invalid_values|
        post "/dsa/illegal-content.json", params: { notice: notice.merge(invalid_values) }
        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to be_present
      end
    end

    it "rejects structured values in scalar fields" do
      post "/dsa/illegal-content.json", params: { notice: notice.merge(explanation: ["x" * 100]) }
      expect(response.status).to eq(422)
      post "/dsa/illegal-content.json", params: { notice: [notice] }
      expect(response.status).to eq(422)
    end

    it "rejects changed content under an already accepted submission identity" do
      post "/dsa/illegal-content.json", params: { notice: }
      expect(response.status).to eq(201)
      post "/dsa/illegal-content.json", params: { notice: notice.merge(anonymous: true) }
      expect(response.status).to eq(409)
    end

    it "returns not found when disabled" do
      SiteSetting.dsa_reporting_enabled = false
      post "/dsa/illegal-content.json", params: { notice: }
      expect(response.status).to eq(404)
    end

    it "limits contact notices to three per email address per day" do
      RateLimiter.enable
      3.times do
        post "/dsa/illegal-content.json",
             params: {
               notice: notice.merge(submission_id: SecureRandom.uuid),
             }
        expect(response.status).to eq(201)
      end
      post "/dsa/illegal-content.json",
           params: {
             notice: notice.merge(submission_id: SecureRandom.uuid, email: notice[:email].upcase),
           }
      expect(response.status).to eq(429)
    end

    it "requires CSRF protection for public submissions" do
      ActionController::Base.allow_forgery_protection = true
      expect do post "/dsa/illegal-content.json", params: { notice: } end.not_to change(
        Topic,
        :count,
      )
      expect(response.status).to eq(403)
    ensure
      ActionController::Base.allow_forgery_protection = false
    end

    it "keeps saved notices inaccessible to unrelated users" do
      post "/dsa/illegal-content.json", params: { notice: }
      expect(response.status).to eq(201)
      reference = response.parsed_body["reference"]
      topic = Topic.find_by!(title: I18n.t("dsa_notice.subject", reference:))
      sign_in(Fabricate(:user))
      get "/t/#{topic.id}.json"
      expect(response.status).to be_between(400, 499)
      expect(response.body).not_to include(notice[:explanation], notice[:name], notice[:email])
    end

    it "allows a saved notice to recover from a queue failure without duplication" do
      Jobs.stubs(:enqueue).returns("queued")
      Jobs.stubs(:enqueue).with(:dsa_notice_receipt, anything).raises(IOError, "queue unavailable")
      expect do post "/dsa/illegal-content.json", params: { notice: } end.to change(
        Topic,
        :count,
      ).by(1)
      expect(response.status).to eq(503)
      Jobs.unstub(:enqueue)

      expect do post "/dsa/illegal-content.json", params: { notice: } end.not_to change(
        Topic,
        :count,
      )
      expect(response.status).to eq(201)
    end

    it "limits new notices per IP while allowing retries of accepted notices" do
      RateLimiter.enable
      first_notice = notice.merge(anonymous: true)
      5.times do |index|
        payload = index.zero? ? first_notice : first_notice.merge(submission_id: SecureRandom.uuid)
        post "/dsa/illegal-content.json", params: { notice: payload }
        expect(response.status).to eq(201)
      end
      post "/dsa/illegal-content.json",
           params: {
             notice: first_notice.merge(submission_id: SecureRandom.uuid),
           }
      expect(response.status).to eq(429)
      post "/dsa/illegal-content.json", params: { notice: first_notice }
      expect(response.status).to eq(201)
    end
  end
end
