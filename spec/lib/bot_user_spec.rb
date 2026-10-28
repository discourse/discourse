# frozen_string_literal: true

RSpec.describe BotUser do
  before { PluginStore.remove(described_class::STORE_NAMESPACE, described_class::FLOOR_KEY) }

  describe ".next_id" do
    it "allocates consecutive IDs below the reserved region without creating users" do
      ids = nil
      expect { ids = 2.times.map { described_class.next_id } }.not_to change(User, :count)

      expect(ids).to eq([-1201, -1202])
      expect(described_class.floor).to eq(-1202)
    end

    it "starts below existing users and does not reuse a deleted user's ID" do
      existing_user = Fabricate(:user, id: -3000)
      first_id = described_class.next_id
      bot = Fabricate(:user, id: first_id)

      bot.destroy!
      existing_user.destroy!

      expect(first_id).to eq(-3001)
      expect(described_class.next_id).to eq(-3002)
    end

    it "continues using the existing persisted allocation floor" do
      PluginStore.set("discourse-ai", "bot_user_id_floor", -5000)

      expect(described_class.next_id).to eq(-5001)
      expect(PluginStore.get("discourse-ai", "bot_user_id_floor")).to eq(-5001)
    end
  end
end
