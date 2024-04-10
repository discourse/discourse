# frozen_string_literal: true

RSpec.describe ThemeSettingsManager::Objects do
  fab!(:theme)

  let(:theme_setting) do
    yaml = File.read("#{Rails.root}/spec/fixtures/theme_settings/objects_settings.yaml")
    field = theme.set_field(target: :settings, name: "yaml", value: yaml)
    theme.save!
    theme.settings
  end

  it "can store a list of objects" do
    new_value = [
      {
        "name" => "section 3",
        "links" => [
          { "name" => "section 3 link 1", "url" => "https://section3link1.com" },
          { "name" => "section 3 link 2" },
        ],
      },
      {
        "name" => "section 4",
        "links" => [{ "name" => "section 4 link 1", "url" => "https://section4link1.com" }],
      },
    ]

    theme_setting[:objects_setting].value = new_value

    expect(theme.reload.settings[:objects_setting].value).to eq(new_value)
  end

  it "raises the right error when there are objects which are not valid" do
    new_value = [
      { "name" => "section 3", "links" => [{ "url" => "https://some.url.no.name" }] },
      {
        "links" => [
          {
            "name" => "some name that exceeds the max length of 20 characters",
            "url" => "https://some.url",
          },
        ],
      },
    ]

    expect { theme_setting[:objects_setting].value = new_value }.to raise_error(
      Discourse::InvalidParameters,
      "The property at JSON Pointer '/0/links/0/name' must be present. The property at JSON Pointer '/1/name' must be present. The property at JSON Pointer '/1/links/0/name' must be at most 20 characters long.",
    )
  end

  describe "#categories" do
    fab!(:category_1) { Fabricate(:category) }
    fab!(:category_2) { Fabricate(:category) }
    fab!(:category_3) { Fabricate(:private_category, group: Fabricate(:group)) }
    fab!(:admin)

    it "returns an empty array when there are no properties of `categories` type" do
      expect(theme_setting[:objects_setting].categories(Guardian.new)).to eq([])
    end

    it "returns the categories record for all the properties of `categories` type in a flat array" do
      new_value = [
        {
          "category_ids" => [category_1.id, category_2.id],
          "child_categories" => [{ "category_ids" => [category_3.id] }],
        },
      ]

      theme_setting[:objects_with_categories].value = new_value

      expect(theme.reload.settings[:objects_with_categories].value).to eq(new_value)

      expect(theme.settings[:objects_with_categories].categories(Guardian.new)).to contain_exactly(
        category_1,
        category_2,
      )

      expect(
        theme.settings[:objects_with_categories].categories(Guardian.new(admin)),
      ).to contain_exactly(category_1, category_2, category_3)
    end
  end
end
