# frozen_string_literal: true

RSpec.describe "Pre-rename /voice routes" do
  before { SiteSetting.live_enabled = true }

  it "redirects room links to /live, keeping the query string" do
    get "/voice/r/watercooler/invited-by/sam?join"

    expect(response).to redirect_to("/live/r/watercooler/invited-by/sam?join")
  end

  it "keeps the subfolder prefix when redirecting" do
    set_subfolder "/forum"

    get "/voice/r/watercooler"

    expect(response).to redirect_to("/forum/live/r/watercooler")
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
