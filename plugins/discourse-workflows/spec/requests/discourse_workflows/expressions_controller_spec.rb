# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::ExpressionsController do
  fab!(:admin)
  fab!(:user_1, :user)

  before { sign_in(admin) }

  describe "POST /admin/plugins/discourse-workflows/expressions/evaluate" do
    let(:endpoint) { "/admin/plugins/discourse-workflows/expressions/evaluate.json" }

    it "returns the resolved segments for a valid template" do
      post endpoint, params: { template: "Hello world" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["segments"]).to contain_exactly(
        { "kind" => "plaintext", "text" => "Hello world" },
      )
    end

    it "is rate limited" do
      RateLimiter.enable

      freeze_time do
        30.times do
          post endpoint, params: { template: "test" }
          expect(response).to have_http_status(:ok)
        end

        post endpoint, params: { template: "test" }
        expect(response).to have_http_status(:too_many_requests)
      end
    ensure
      RateLimiter.disable
    end

    it "requires the template parameter" do
      post endpoint, params: {}
      expect(response).to have_http_status(:bad_request)
    end

    it "requires admin access" do
      sign_in(user_1)
      post endpoint, params: { template: "test" }
      expect(response).to have_http_status(:not_found)
    end
  end
end
