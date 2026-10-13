# frozen_string_literal: true

RSpec.describe "Pre-rename /voice routes" do
  before { SiteSetting.live_enabled = true }

  it "redirects room links to /live, keeping the query string" do
    get "/voice/r/watercooler/invited-by/sam?join"

    expect(response).to redirect_to("/live/r/watercooler/invited-by/sam?join")
  end

  it "still routes LiveKit webhooks to the webhook controller" do
    post "/voice/livekit/webhook",
         params: "{}",
         headers: {
           "CONTENT_TYPE" => "application/webhook+json",
         }

    expect(response.status).to eq(403)
  end
end
