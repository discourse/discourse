# frozen_string_literal: true

RSpec.describe DsaNoticesController do
  fab!(:group)

  let(:email) { "alex@example.com" }
  let(:notice) do
    {
      content_url: "#{Discourse.base_url}/t/reported-content/123/4",
      explanation:
        "This listing advertises counterfeit goods as authentic and its payment instructions appear intended to deceive buyers.",
      name: "Alex Morgan",
      email:,
      declaration: true,
    }
  end

  before do
    SiteSetting.dsa_reporting_enabled = true
    SiteSetting.dsa_notice_group = group.id.to_s
  end

  describe "#index" do
    it "serves the form without login on a private site" do
      SiteSetting.login_required = true
      get "/dsa/report-illegal-content"
      expect(response.status).to eq(200)
      get "/dsa/report-illegal-content.json"
      expect(response.status).to eq(406)
    end

    it "returns not found when disabled" do
      SiteSetting.dsa_reporting_enabled = false
      get "/dsa/report-illegal-content"
      expect(response.status).to eq(404)
    end
  end

  describe "#verify_email" do
    it "requests a code without requiring report details or login" do
      SiteSetting.login_required = true

      expect do
        post "/dsa/report-illegal-content/verify-email.json", params: { email: }
      end.not_to change(Dsa::Notice, :count)

      expect(response.status).to eq(202)
      expect(response.parsed_body.keys).to contain_exactly("token")
      expect(response.parsed_body["token"]).to match(/\A[0-9a-f]{64}\z/)
    end

    it "returns not found when disabled" do
      SiteSetting.dsa_reporting_enabled = false
      post "/dsa/report-illegal-content/verify-email.json", params: { email: }
      expect(response.status).to eq(404)
    end

    it "returns email validation errors as unprocessable content" do
      post "/dsa/report-illegal-content/verify-email.json", params: { email: "invalid" }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to be_present
    end

    it "returns too many requests when requesting a code is rate limited" do
      RateLimiter.enable
      5.times { RateLimiter.new(nil, "dsa-notice-ip-127.0.0.1", 5, 1.hour).performed! }

      post "/dsa/report-illegal-content/verify-email.json", params: { email: }

      expect(response.status).to eq(429)
    end

    it "requires CSRF protection for code requests" do
      ActionController::Base.allow_forgery_protection = true
      post "/dsa/report-illegal-content/verify-email.json", params: { email: }
      expect(response.status).to eq(403)
    ensure
      ActionController::Base.allow_forgery_protection = false
    end
  end

  describe "#verify_code" do
    let(:token) { Dsa::NoticeVerification.create(email) }
    let(:verification_code) { Dsa::NoticeVerification.find(token)[:code] }
    let(:params) { { email:, token:, verification_code: } }

    it "verifies the email without login or creating a report" do
      SiteSetting.login_required = true

      expect do
        post "/dsa/report-illegal-content/verify-code.json", params: params
      end.not_to change(Dsa::Notice, :count)

      expect(response.status).to eq(200)
    end

    it "returns an actionable error for an unavailable verification" do
      post "/dsa/report-illegal-content/verify-code.json",
           params: {
             email:,
             token: "a" * 64,
             verification_code: "123456",
           }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to eq([I18n.t("dsa_notice.verification_invalid")])
    end

    it "returns too many requests when code verification attempts are exhausted" do
      RateLimiter.enable
      5.times do
        RateLimiter.new(nil, "dsa-notice-verification-attempts-#{token}", 5, 30.minutes).performed!
      end

      post "/dsa/report-illegal-content/verify-code.json", params: params

      expect(response.status).to eq(429)
    end

    it "returns not found when disabled" do
      SiteSetting.dsa_reporting_enabled = false
      post "/dsa/report-illegal-content/verify-code.json", params: params
      expect(response.status).to eq(404)
    end

    it "requires CSRF protection for verifying codes" do
      ActionController::Base.allow_forgery_protection = true
      post "/dsa/report-illegal-content/verify-code.json", params: params
      expect(response.status).to eq(403)
    ensure
      ActionController::Base.allow_forgery_protection = false
    end
  end

  describe "#create" do
    let(:token) do
      pending_token = Dsa::NoticeVerification.create(email)
      code = Dsa::NoticeVerification.find(pending_token)[:code]
      Dsa::NoticeVerification.verify(token: pending_token, email:, code:)
      pending_token
    end
    let(:params) { { notice:, token: } }

    it "accepts a report with a verified email without login and returns its reference" do
      SiteSetting.login_required = true
      post "/dsa/report-illegal-content.json", params: params

      expect(response.status).to eq(201)
      expect(response.parsed_body["reference"]).to start_with("DSA-")
    end

    it "uses the signed in reporter's account email regardless of the submitted address" do
      reporter = Fabricate(:user)
      reporter.activate
      sign_in(reporter)

      post "/dsa/report-illegal-content.json", params: { notice:, token: "" }

      expect(response.status).to eq(201)
      saved_notice = Dsa::Notice.last
      expect(response.parsed_body["reference"]).to eq(saved_notice.reference)
      expect(saved_notice.email).to eq(reporter.email)
    end

    it "limits account submissions independently of email verification requests" do
      reporter = Fabricate(:user)
      reporter.activate
      RateLimiter.enable

      stub_const(Dsa::NoticeRateLimiter, :MAX_REQUESTS_PER_REPORTER_PER_DAY, 1) do
        post "/dsa/report-illegal-content/verify-email.json", params: { email: reporter.email }
        expect(response.status).to eq(202)

        sign_in(reporter)

        post "/dsa/report-illegal-content.json", params: { notice:, token: "" }
        expect(response.status).to eq(201)

        expect do
          post "/dsa/report-illegal-content.json", params: { notice:, token: "" }
        end.not_to change(Dsa::Notice, :count)

        expect(response.status).to eq(429)
      end
    end

    it "lets an anonymous mode reporter submit only with a verified contact email" do
      SiteSetting.allow_anonymous_mode = true
      SiteSetting.anonymous_posting_allowed_groups = Group::AUTO_GROUPS[:trust_level_1].to_s
      reporter = Fabricate(:user, trust_level: TrustLevel[3])
      sign_in(AnonymousShadowCreator.get(reporter))
      SiteSetting.allow_anonymous_mode = false

      expect do
        post "/dsa/report-illegal-content.json", params: { notice:, token: "" }
      end.not_to change(Dsa::Notice, :count)

      expect(response.status).to eq(422)
      expect(response.parsed_body["error_type"]).to eq("verification_required")

      post "/dsa/report-illegal-content.json", params: params

      expect(response.status).to eq(201)
      expect(Dsa::Notice.last.email).to eq(email)
    end

    it "requires verification when the signed in reporter's account email is unconfirmed" do
      reporter = Fabricate(:user)
      sign_in(reporter)
      Fabricate(:email_token, user: reporter)

      expect do post "/dsa/report-illegal-content.json", params: { notice: } end.not_to change(
        Dsa::Notice,
        :count,
      )

      expect(response.status).to eq(422)
      expect(response.parsed_body["error_type"]).to eq("verification_required")
    end

    it "requires email verification for an anonymous report without a token" do
      expect do post "/dsa/report-illegal-content.json", params: { notice: } end.not_to change(
        Dsa::Notice,
        :count,
      )

      expect(response.status).to eq(422)
      expect(response.parsed_body["error_type"]).to eq("verification_required")
    end

    it "returns not found when disabled" do
      SiteSetting.dsa_reporting_enabled = false
      post "/dsa/report-illegal-content.json", params: params
      expect(response.status).to eq(404)
    end

    it "returns report validation errors as unprocessable content" do
      params[:notice][:declaration] = false
      post "/dsa/report-illegal-content.json", params: params

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to be_present
    end

    it "returns an actionable error when the email verification is unavailable" do
      post "/dsa/report-illegal-content.json", params: { notice:, token: "a" * 64 }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to eq([I18n.t("dsa_notice.verification_invalid")])
      expect(response.parsed_body["error_type"]).to eq("verification_required")
    end

    it "returns a generic failure when the notice cannot be saved" do
      exception = ActiveRecord::RecordNotSaved.new("save failed")
      PostCreator.stubs(:create!).raises(exception)
      post "/dsa/report-illegal-content.json", params: params

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to eq([I18n.t("js.generic_error")])
    end

    it "requires CSRF protection for report submission" do
      ActionController::Base.allow_forgery_protection = true
      post "/dsa/report-illegal-content.json", params: params
      expect(response.status).to eq(403)
    ensure
      ActionController::Base.allow_forgery_protection = false
    end
  end
end
