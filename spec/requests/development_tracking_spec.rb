# frozen_string_literal: true

RSpec.describe "Development tracking" do
  describe "POST /srv/se" do
    let(:development) { true }
    let(:router) { Rack::MockRequest.new(Rails.application.routes) }

    before do
      Rails.env.stubs(:development?).returns(development)
      Rails.application.reload_routes!
    end

    after do
      Rails.env.unstub(:development?)
      Rails.application.reload_routes!
    end

    it "discards stale engagement beacons when request tracking middleware is absent" do
      payload = { session_id: "stale-session", click_events: 1, key_events: 1 }.to_json

      expect {
        response = router.post("/srv/se", "CONTENT_TYPE" => "application/json", :input => payload)

        expect(response.status).to eq(204)
        expect(response.body).to be_empty
      }.not_to change { BrowserPageviewSessionEngagement.count }
    end

    context "when outside development" do
      let(:development) { false }

      it "leaves engagement requests to the request tracking middleware" do
        response = router.post("/srv/se")

        expect(response.status).to eq(404)
      end
    end
  end
end
