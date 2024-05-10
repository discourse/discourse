# frozen_string_literal: true

RSpec.describe ThemeObjectsSettingMetadataSerializer do
  fab!(:theme)

  let(:theme_setting) do
    yaml = File.read("#{Rails.root}/spec/fixtures/theme_settings/objects_settings.yaml")
    theme.set_field(target: :settings, name: "yaml", value: yaml)
    theme.save!
    theme.settings
  end

  describe "#property_descriptions" do
    let(:objects_setting_locale) do
      theme.set_field(
        target: :translations,
        name: "en",
        value: File.read("#{Rails.root}/spec/fixtures/theme_locales/objects_settings/en.yaml"),
      )

      theme.save!
    end

    it "should return a hash of the settings property descriptions" do
      objects_setting_locale

      payload = described_class.new(theme_setting[:objects_setting], root: false).as_json

      expect(payload[:property_descriptions]).to eq(
        {
          "links.name.description" => "Name of the link",
          "links.name.label" => "Name",
          "links.url.description" => "URL of the link",
          "links.url.label" => "URL",
          "name.description" => "Section Name",
          "name.label" => "Name",
        },
      )
    end
  end

  describe "#categories" do
    fab!(:category_1) { Fabricate(:category) }
    fab!(:category_2) { Fabricate(:category) }
    fab!(:category_3) { Fabricate(:private_category, group: Fabricate(:group)) }
    fab!(:admin)

    it "should return a hash of serialized categories" do
      theme_setting[:objects_with_categories].value = [
        {
          "category_ids" => [category_1.id, category_2.id],
          "child_categories" => [{ "category_ids" => [category_3.id] }],
        },
      ]

      scope = Guardian.new

      payload =
        described_class.new(theme_setting[:objects_with_categories], scope:, root: false).as_json

      categories = payload[:categories]

      expect(categories.keys).to contain_exactly(category_1.id, category_2.id)

      expect(categories[category_1.id]).to eq(
        BasicCategorySerializer.new(category_1, scope:, root: false).as_json,
      )

      expect(categories[category_2.id]).to eq(
        BasicCategorySerializer.new(category_2, scope:, root: false).as_json,
      )

      scope = Guardian.new(admin)

      payload =
        described_class.new(theme_setting[:objects_with_categories], scope:, root: false).as_json

      categories = payload[:categories]

      expect(categories.keys).to contain_exactly(category_1.id, category_2.id, category_3.id)

      expect(categories[category_1.id]).to eq(
        BasicCategorySerializer.new(category_1, scope:, root: false).as_json,
      )

      expect(categories[category_2.id]).to eq(
        BasicCategorySerializer.new(category_2, scope:, root: false).as_json,
      )

      expect(categories[category_3.id]).to eq(
        BasicCategorySerializer.new(category_3, scope:, root: false).as_json,
      )
    end
  end
end
