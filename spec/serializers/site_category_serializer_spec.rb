# frozen_string_literal: true

describe SiteCategorySerializer do
  fab!(:user)
  fab!(:category)

  describe "name" do
    it "returns the name of the category" do
      json = described_class.new(category, scope: Guardian.new(user), root: false).as_json
      expect(json[:name]).to eq(category.name)
    end

    it "returns the uncategorized name if the category is uncategorized" do
      SiteSetting.uncategorized_category_id = category.id
      json = described_class.new(category, scope: Guardian.new(user), root: false).as_json
      expect(json[:name]).to eq(
        I18n.t("uncategorized_category_name", locale: SiteSetting.default_locale),
      )
    end

    it "applies the registered modifier" do
      plugin = Plugin::Instance.new
      modifier = :site_category_serializer_name
      proc = Proc.new { "X" }
      DiscoursePluginRegistry.register_modifier(plugin, modifier, &proc)

      json = described_class.new(category, scope: Guardian.new(user), root: false).as_json
      expect(json[:name]).to eq("X")
    ensure
      DiscoursePluginRegistry.unregister_modifier(plugin, modifier, &proc)
    end
  end
end
