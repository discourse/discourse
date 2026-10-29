# frozen_string_literal: true

RSpec.describe BotUser do
  subject(:allocator) { described_class.new(:core) }

  before { PluginStoreRow.where(key: described_class::FLOOR_KEY).delete_all }

  describe "#next_id" do
    it "allocates consecutive IDs below the reserved region without creating users" do
      ids = nil
      expect { ids = 2.times.map { allocator.next_id } }.not_to change(User, :count)

      expect(ids).to eq([-1201, -1202])
      expect(PluginStore.get("core", described_class::FLOOR_KEY)).to eq(-1202)
    end

    it "reserves distinct IDs across namespaces and instances before users are persisted" do
      other_allocator = described_class.new("another-plugin")
      ids = nil

      expect do
        ids = [allocator.next_id, other_allocator.next_id, described_class.new("core").next_id]
      end.not_to change(User, :count)

      expect(ids).to eq([-1201, -1202, -1203])
      expect(PluginStore.get("core", described_class::FLOOR_KEY)).to eq(-1203)
      expect(PluginStore.get("another-plugin", described_class::FLOOR_KEY)).to eq(-1202)
    end

    it "starts below existing users and does not reuse a deleted user's ID" do
      existing_user = Fabricate(:user, id: -3000)
      first_id = allocator.next_id
      bot = Fabricate(:user, id: first_id)

      bot.destroy!
      existing_user.destroy!

      expect(first_id).to eq(-3001)
      expect(described_class.new("core").next_id).to eq(-3002)
    end

    it "continues below legacy reservations while storing new reservations in its namespace" do
      PluginStore.set("legacy-plugin", described_class::FLOOR_KEY, -5000)
      PluginStoreRow.where(
        plugin_name: "legacy-plugin",
        key: described_class::FLOOR_KEY,
      ).update_all(type_name: "Fixnum")

      expect(allocator.next_id).to eq(-5001)
      expect(PluginStore.get("core", described_class::FLOOR_KEY)).to eq(-5001)
      expect(PluginStore.get("legacy-plugin", described_class::FLOOR_KEY)).to eq(-5000)
    end

    it "uses the lowest integer reservation across namespaces" do
      PluginStore.set("first-plugin", described_class::FLOOR_KEY, -9000)
      PluginStore.set("second-plugin", described_class::FLOOR_KEY, -10_000)
      PluginStore.set("unrelated-plugin", described_class::FLOOR_KEY, "-20000")

      expect(allocator.next_id).to eq(-10_001)
    end
  end
end
