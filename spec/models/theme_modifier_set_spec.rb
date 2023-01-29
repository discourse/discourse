# frozen_string_literal: true
RSpec.describe ThemeModifierSet do
  describe "#resolve_modifiers_for_themes" do
    it "returns nil for unknown modifier" do
      expect(ThemeModifierSet.resolve_modifier_for_themes([1, 2], :unknown_modifier)).to eq(nil)
    end

    it "resolves serialize_topic_excerpts correctly" do
      t1 = Fabricate(:theme)
      t1.theme_modifier_set.update!(serialize_topic_excerpts: true)
      t2 = Fabricate(:theme)
      t2.theme_modifier_set.update!(serialize_topic_excerpts: false)

      expect(
        ThemeModifierSet.resolve_modifier_for_themes([t1.id, t2.id], :serialize_topic_excerpts),
      ).to eq(true)

      t1 = Fabricate(:theme)
      t1.theme_modifier_set.update!(serialize_topic_excerpts: nil)

      expect(
        ThemeModifierSet.resolve_modifier_for_themes([t1.id, t2.id], :serialize_topic_excerpts),
      ).to eq(false)
    end

    it "builds modifiers list from database" do
      expect(ThemeModifierSet.modifiers.keys).to include(:serialize_topic_excerpts, :csp_extensions)
      expect(ThemeModifierSet.modifiers[:serialize_topic_excerpts][:type]).to eq(:boolean)
      expect(ThemeModifierSet.modifiers[:csp_extensions][:type]).to eq(:string_array)
    end
  end
end
