# frozen_string_literal: true

# We can use the redeliver event to test the user-agent header
RSpec.describe "Net::HTTPHeader sets a default user-agent" do
  it "should set a user-agent when none has been set" do
    get "/test_net_http_headers.json"

    expect(response).to have_http_status(:success)

    parsed_body = JSON.parse(response.body)
    expect(parsed_body).to have_key("user-agent")
    expect(parsed_body["user-agent"].first).to eq(Discourse.user_agent)
  end
end
