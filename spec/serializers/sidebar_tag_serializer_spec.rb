# frozen_string_literal: true

RSpec.describe SidebarTagSerializer do
  fab!(:user)
  fab!(:localized_tag, :tag) { Fabricate(:tag, name: "strategic_access", locale: "en") }
  fab!(:localization) { Fabricate(:tag_localization, tag: localized_tag, locale: "ja", name: "戦略") }

  def serialize(tag)
    described_class.new(tag, scope: Guardian.new(user), root: false).as_json
  end

  describe "#original_name" do
    it "is included alongside the localized name" do
      SiteSetting.content_localization_enabled = true
      I18n.locale = "ja"

      serialized = serialize(localized_tag)

      expect(serialized[:name]).to eq("戦略")
      expect(serialized[:original_name]).to eq("strategic_access")
    end

    it "is omitted when the name is not localized" do
      SiteSetting.content_localization_enabled = false
      I18n.locale = "ja"

      serialized = serialize(localized_tag)

      expect(serialized[:name]).to eq("strategic_access")
      expect(serialized).not_to have_key(:original_name)
    end
  end
end
