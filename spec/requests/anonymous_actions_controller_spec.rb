# frozen_string_literal: true

RSpec.describe AnonymousActionsController do
  let(:type) { "anon_actions_controller_spec_test" }

  before { AnonymousAction.register(type) { |_, _| } }
  after { AnonymousAction.unregister(type) }

  def do_post(payload = { type:, params: {} })
    post "/anonymous-action.json", params: payload
  end

  describe "#create" do
    it "sets a signed cookie for a registered type" do
      do_post(type:, params: { post_id: 42 })

      expect(response.status).to eq(204)
      expect(response.cookies[AnonymousAction::COOKIE.to_s]).to be_present
    end

    it "rejects unknown action types" do
      do_post(type: "ghost_action", params: {})

      expect(response.status).to eq(400)
    end

    it "requires the type param" do
      do_post(params: { post_id: 1 })

      expect(response.status).to eq(400)
    end

    it "rejects logged-in users" do
      sign_in(Fabricate(:user))

      do_post(type:, params: { post_id: 42 })

      expect(response.status).to eq(403)
      expect(response.cookies[AnonymousAction::COOKIE.to_s]).to be_nil
    end

    it "rejects oversized params" do
      do_post(type:, params: { junk: "x" * (AnonymousActionsController::MAX_PARAMS_BYTES + 1) })

      expect(response.status).to eq(400)
      expect(response.cookies[AnonymousAction::COOKIE.to_s]).to be_nil
    end

    context "when rate-limited" do
      before { RateLimiter.enable }

      it "returns 429 after exceeding the per-minute limit" do
        10.times do
          do_post
          expect(response.status).to eq(204)
        end

        do_post

        expect(response.status).to eq(429)
        expect(response.parsed_body["error_type"]).to eq("rate_limit")
      end
    end
  end
end
