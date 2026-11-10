# frozen_string_literal: true

RSpec.describe ::BotUser do
  subject(:allocator) { described_class.new(DiscourseAi::PLUGIN_NAME) }

  before do
    enable_current_plugin
    PluginStoreRow.where(key: described_class::FLOOR_KEY).delete_all
  end

  describe "#next_id" do
    it "shares reservations between core and plugin namespaces" do
      PluginStore.set(DiscourseAi::PLUGIN_NAME, described_class::FLOOR_KEY, -5000)
      core_allocator = described_class.new("core")

      expect([core_allocator.next_id, allocator.next_id, core_allocator.next_id]).to eq(
        [-5001, -5002, -5003],
      )
      expect(PluginStore.get("core", described_class::FLOOR_KEY)).to eq(-5003)
      expect(PluginStore.get(DiscourseAi::PLUGIN_NAME, described_class::FLOOR_KEY)).to eq(-5003)
    end

    it "shares unpersisted reservations with workers using the legacy allocator" do
      core_allocator = described_class.new("core")
      ids = []

      expect do
        ids << core_allocator.next_id
        expect(PluginStore.get(DiscourseAi::PLUGIN_NAME, described_class::FLOOR_KEY)).to eq(
          ids.last,
        )

        legacy_id =
          DistributedMutex.synchronize(
            "#{DiscourseAi::PLUGIN_NAME}_#{described_class::FLOOR_KEY}",
          ) do
            legacy_floor = PluginStore.get(DiscourseAi::PLUGIN_NAME, described_class::FLOOR_KEY)
            id = [User.minimum(:id), described_class::FIRST_ID, legacy_floor].compact.min - 1
            PluginStore.set(DiscourseAi::PLUGIN_NAME, described_class::FLOOR_KEY, id)
            id
          end
        ids << legacy_id
        ids << allocator.next_id
        ids << core_allocator.next_id
      end.not_to change(User, :count)

      expect(ids).to eq([-1201, -1202, -1203, -1204])
      expect(PluginStore.get("core", described_class::FLOOR_KEY)).to eq(-1204)
      expect(PluginStore.get(DiscourseAi::PLUGIN_NAME, described_class::FLOOR_KEY)).to eq(-1204)
    end

    it "reserves dangling agent references before either creation path allocates" do
      agent = Fabricate(:ai_agent)
      agent.update_columns(user_id: -6000)

      expect(described_class.new("core").next_id).to eq(-6001)
      expect(allocator.next_id).to eq(-6002)
    end

    it "reserves dangling model references even when the plugin is disabled" do
      model = Fabricate(:llm_model)
      model.update_columns(user_id: -9000)
      SiteSetting.discourse_ai_enabled = false

      expect(described_class.new("core").next_id).to eq(-9001)
      expect(allocator.next_id).to eq(-9002)
    end
  end
end
