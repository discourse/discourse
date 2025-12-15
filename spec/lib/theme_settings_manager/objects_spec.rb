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
    fab!(:category_1, :category)
    fab!(:category_2, :category)
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

  describe "upload hydration" do
    fab!(:upload1, :upload)
    fab!(:upload2, :upload)

    it "hydrates upload IDs to URLs when serialized" do
      yaml = <<~YAML
        objects_with_uploads:
          type: objects
          default: []
          schema:
            name: item
            properties:
              name:
                type: string
              banner:
                type: upload
              nested:
                type: objects
                schema:
                  name: nested_item
                  properties:
                    icon:
                      type: upload
      YAML

      theme.set_field(target: :settings, name: "yaml", value: yaml)
      theme.save!

      new_value = [
        { "name" => "item 1", "banner" => upload1.id, "nested" => [{ "icon" => upload2.id }] },
      ]

      theme.settings[:objects_with_uploads].value = new_value
      theme.reload

      # The raw value should still have IDs (not hydrated)
      raw_value = theme.settings[:objects_with_uploads].value
      expect(raw_value[0]["banner"]).to eq(upload1.id)
      expect(raw_value[0]["nested"][0]["icon"]).to eq(upload2.id)

      # But when serialized, upload IDs should be hydrated to URLs
      serialized = ThemeSettingsSerializer.new(theme.settings[:objects_with_uploads], root: false)
      expect(serialized.value[0]["banner"]).to eq(upload1.url)
      expect(serialized.value[0]["nested"][0]["icon"]).to eq(upload2.url)
    end
  end
end
