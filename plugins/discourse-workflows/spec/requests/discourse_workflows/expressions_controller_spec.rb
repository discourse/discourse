# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::ExpressionsController do
  fab!(:admin)

  before { sign_in(admin) }

  describe "POST /admin/plugins/discourse-workflows/expressions/evaluate" do
    let(:endpoint) { "/admin/plugins/discourse-workflows/expressions/evaluate.json" }

    it "returns the resolved segments for a valid template" do
      post endpoint, params: { template: "Hello world" }

      expect(response.status).to eq(200)
      expect(response.parsed_body["segments"]).to contain_exactly(
        { "kind" => "plaintext", "text" => "Hello world" },
      )
    end

    it "is rate limited" do
      RateLimiter.enable
      freeze_time

      30.times do
        post endpoint, params: { template: "test" }
        expect(response.status).to eq(200)
      end

      post endpoint, params: { template: "test" }
      expect(response.status).to eq(429)
    end

    it "requires the template parameter" do
      post endpoint, params: {}
      expect(response.status).to eq(400)
    end

    it "requires admin access" do
      sign_in(Fabricate(:user))
      post endpoint, params: { template: "test" }
      expect(response.status).to eq(404)
    end
  end
end
