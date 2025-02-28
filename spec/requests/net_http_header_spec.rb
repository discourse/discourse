# frozen_string_literal: true

# We can use the redeliver event to test the user-agent header
RSpec.describe "Net::HTTPHeader sets a default user-agent" do
  fab!(:admin)
  fab!(:web_hook)
  let!(:web_hook_event) { WebHookEvent.create!(web_hook: web_hook, headers: "{}") }

  before do
    sign_in(admin)
    stub_request(:post, web_hook.payload_url)
  end

  it "should set a user-agent when none has been set" do
    post "/admin/api/web_hooks/#{web_hook.id}/events/#{web_hook_event.id}/redeliver.json"

    expect(JSON.parse(response.parsed_body["web_hook_event"]["response_headers"])).to eq(
      {
        "user-agent" =>
          "Discourse/#{Discourse::VERSION::STRING}-#{Discourse.git_version}; +https://www.discourse.org/",
      },
    )
  end
end
