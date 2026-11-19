# frozen_string_literal: true

RSpec.describe AdPlugin::DfpCategorySetting do
  fab!(:category)

  before { enable_current_plugin }

  describe "#save" do
    it "rejects a nonexistent category" do
      setting = described_class.new(category_id: -1, gam_adunit: "/123/travel")

      expect(setting.save).to eq(false)
      expect(setting.errors[:category]).to be_present
    end
  end

  describe "category lifecycle" do
    it "removes settings without broadcasting when a category is destroyed while the plugin is disabled" do
      setting = described_class.create!(category: category, gam_adunit: "/123/travel")
      SiteSetting.discourse_adplugin_enabled = false

      messages =
        MessageBus.track_publish("/site/dfp-category-settings/changed") { category.destroy! }

      expect(described_class.exists?(setting.id)).to eq(false)
      expect(messages).to be_empty
    end

    it "removes settings and broadcasts the updated map when a category is destroyed" do
      setting = described_class.create!(category: category, gam_adunit: "/123/travel")

      messages =
        MessageBus.track_publish("/site/dfp-category-settings/changed") { category.destroy! }

      expect(described_class.exists?(setting.id)).to eq(false)
      expect(messages.last.data.with_indifferent_access[:public]).not_to have_key(category.id.to_s)
    end

    it "broadcasts a public map without the category after it becomes private" do
      setting = described_class.create!(category: category, gam_keywords: "private-keywords")
      group = Fabricate(:group)

      messages =
        MessageBus.track_publish("/site/dfp-category-settings/changed") do
          category.set_permissions(group => :full)
          category.save!
        end

      payload = messages.last.data.with_indifferent_access
      expect(payload[:secure]).to eq(true)
      expect(payload[:public]).not_to have_key(category.id.to_s)
      expect(payload.to_json).not_to include(setting.gam_keywords)
      expect(described_class.site_settings_for(Fabricate(:user).guardian)).to eq({})
    end
  end
end
