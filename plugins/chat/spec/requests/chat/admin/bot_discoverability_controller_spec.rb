# frozen_string_literal: true

RSpec.describe Chat::Admin::BotDiscoverabilityController do
  fab!(:admin)
  fab!(:bot)

  describe "#update" do
    it "saves an admin's change without a response body" do
      sign_in(admin)
      put "/chat/admin/bots/#{bot.id}/discoverability.json", params: { discoverable: true }
      expect(response.status).to eq(204)
      expect(Chat::DiscoverableBot.exists?(user_id: bot.id)).to eq(true)
    end

    it "rejects anonymous visitors, members and moderators" do
      [nil, Fabricate(:user), Fabricate(:moderator)].each do |actor|
        sign_in(actor) if actor
        put "/chat/admin/bots/#{bot.id}/discoverability.json", params: { discoverable: true }
        expect(response.status).to be_in([403, 404])
      end
      expect(Chat::DiscoverableBot.exists?(user_id: bot.id)).to eq(false)
    end
  end
end
