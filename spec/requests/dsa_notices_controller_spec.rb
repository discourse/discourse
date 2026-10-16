# frozen_string_literal: true

RSpec.describe DsaNoticesController do
  fab!(:group)

  before do
    SiteSetting.dsa_reporting_enabled = true
    SiteSetting.dsa_notice_group = group.id.to_s
  end

  describe "#index" do
    it "serves the form without login on a private site" do
      SiteSetting.login_required = true
      get "/dsa/illegal-content"
      expect(response.status).to eq(200)
      get "/dsa/illegal-content.json"
      expect(response.status).to eq(406)
    end

    it "returns not found when disabled" do
      SiteSetting.dsa_reporting_enabled = false
      get "/dsa/illegal-content"
      expect(response.status).to eq(404)
    end
  end

  describe "#create" do
    let(:notice) do
      {
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

    it "returns not found when disabled" do
      SiteSetting.dsa_reporting_enabled = false
      post "/dsa/illegal-content.json", params: { notice: }
      expect(response.status).to eq(404)
    end

    it "returns contract errors as unprocessable content" do
      post "/dsa/illegal-content.json", params: { notice: notice.merge(declaration: false) }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to be_present
    end

    it "returns too many requests when submission is rate limited" do
      RateLimiter.enable
      5.times { RateLimiter.new(nil, "dsa-notice-ip-127.0.0.1", 5, 1.hour).performed! }

      post "/dsa/illegal-content.json", params: { notice: }

      expect(response.status).to eq(429)
    end

    it "returns a generic failure when the notice cannot be saved" do
      exception = ActiveRecord::RecordNotSaved.new("save failed")
      PostCreator.stubs(:create!).raises(exception)
      post "/dsa/illegal-content.json", params: { notice: }
      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to eq([I18n.t("js.generic_error")])
    end

    it "requires CSRF protection for public submissions" do
      ActionController::Base.allow_forgery_protection = true
      post "/dsa/illegal-content.json", params: { notice: }
      expect(response.status).to eq(403)
    ensure
      ActionController::Base.allow_forgery_protection = false
    end
  end
end
