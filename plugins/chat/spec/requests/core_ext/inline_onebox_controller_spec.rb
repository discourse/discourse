# frozen_string_literal: true

RSpec.describe InlineOneboxController do
  fab!(:current_user, :user)
  fab!(:direct_message_user_1, :user)
  fab!(:direct_message_user_2, :user)
  fab!(:public_channel, :category_channel)
  fab!(:private_channel) do
    Fabricate(
      :direct_message_channel,
      users: [direct_message_user_1, direct_message_user_2],
      threading_enabled: true,
    )
  end
  fab!(:private_thread) do
    Fabricate(:chat_thread, channel: private_channel, title: "Private thread title")
  end

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.enable_public_channels = true
    SiteSetting.chat_allowed_groups =
      "#{Group::AUTO_GROUPS[:everyone]}|#{Group::AUTO_GROUPS[:anonymous_users]}"
    sign_in(current_user)
  end

  it "does not disclose a private thread title through a public channel URL" do
    get "/chat/api/channels/#{private_channel.id}/threads/#{private_thread.id}"

    expect(response.status).to eq(403)

    chat_thread_url = "#{Discourse.base_url}/chat/c/-/#{public_channel.id}/t/#{private_thread.id}"
    InlineOneboxer.invalidate(chat_thread_url)

    get "/inline-onebox.json", params: { urls: [chat_thread_url] }

    expect(response.status).to eq(200)
    expect(response.body).not_to include(private_thread.title)
    expect(response.parsed_body["inline-oneboxes"]).to eq([])
  end
end
