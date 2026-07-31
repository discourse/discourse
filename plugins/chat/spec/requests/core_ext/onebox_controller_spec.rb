# frozen_string_literal: true

RSpec.describe OneboxController do
  fab!(:current_user, :user)
  fab!(:direct_message_user_1, :user)
  fab!(:direct_message_user_2, :user)
  fab!(:direct_message_user_3, :user)
  fab!(:public_channel, :category_channel)
  fab!(:private_channel) do
    Fabricate(
      :direct_message_channel,
      users: [direct_message_user_1, direct_message_user_2, direct_message_user_3],
      threading_enabled: true,
    )
  end
  fab!(:private_original_message) do
    Fabricate(
      :chat_message,
      chat_channel: private_channel,
      user: direct_message_user_1,
      message: "private thread secret message",
    )
  end
  fab!(:private_thread) do
    Fabricate(:chat_thread, channel: private_channel, original_message: private_original_message)
  end

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    sign_in(current_user)
  end

  it "does not render a private thread when the URL uses a public channel id" do
    get "/chat/api/channels/#{private_channel.id}/threads/#{private_thread.id}"

    expect(response.status).to eq(403)
    expect(response.parsed_body["errors"]).to be_present

    get "/onebox.json",
        params: {
          url: "#{Discourse.base_url}/chat/c/-/#{public_channel.id}/t/#{private_thread.id}",
          refresh: "true",
        }

    expect(response.status).to eq(200)
    expect(response.body).to include(public_channel.name)
    expect(response.body).not_to include(private_original_message.message)
  end
end
