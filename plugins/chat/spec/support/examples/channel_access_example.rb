# frozen_string_literal: true

RSpec.shared_examples "channel access example" do |verb, endpoint, params|
  endpoint ||= ".json"
  params ||= {}

  context "when channel is not found" do
    before { sign_in(Fabricate(:admin)) }

    it "returns a 404" do
      public_send(verb, "/chat/api/channels/-999#{endpoint}", params: params)
      expect(response.status).to eq(404)
    end
  end

  context "with anonymous user" do
    fab!(:chat_channel) { Fabricate(:category_channel) }

    it "returns a 403" do
      public_send(verb, "/chat/api/channels/#{chat_channel.id}#{endpoint}", params: params)
      expect(response.status).to eq(403)
    end
  end

  context "when channel can’t be seen by current user" do
    fab!(:chatable) { Fabricate(:private_category, group: Fabricate(:group)) }
    fab!(:chat_channel) { Fabricate(:category_channel, chatable: chatable) }
    fab!(:user) { Fabricate(:user) }
    fab!(:membership) do
      Fabricate(:user_chat_channel_membership, user: user, chat_channel: chat_channel)
    end

    before { sign_in(user) }

    it "returns a 403" do
      public_send(verb, "/chat/api/channels/#{chat_channel.id}#{endpoint}", params: params)
      expect(response.status).to eq(403)
    end
  end
end
