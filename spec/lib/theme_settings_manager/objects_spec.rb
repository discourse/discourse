# frozen_string_literal: true

RSpec.describe ThemeSettingsManager::Objects do
  fab!(:theme)

  let(:objects_setting) do
    yaml = File.read("#{Rails.root}/spec/fixtures/theme_settings/objects_settings.yaml")
    field = theme.set_field(target: :settings, name: "yaml", value: yaml)
    theme.save!
    theme.settings[:objects_setting]
  end

  before { SiteSetting.experimental_objects_type_for_theme_settings = true }

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

    objects_setting.value = new_value

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

    expect { objects_setting.value = new_value }.to raise_error(
      Discourse::InvalidParameters,
      "The property at JSON Pointer '/0/links/0/name' must be present. The property at JSON Pointer '/1/name' must be present. The property at JSON Pointer '/1/links/0/name' must be at most 20 characters long.",
    )
  end
end
