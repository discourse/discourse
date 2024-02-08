# frozen_string_literal: true

RSpec.describe ThemeSettingsManager::Objects do
  fab!(:theme)

  before { SiteSetting.experimental_objects_type_for_theme_settings = true }

  it "can store a list of objects" do
    objects_setting =
      described_class.new(
        "some_objects_setting",
        [{ "title" => "Some title", "description" => "Some description" }],
        theme,
        schema: {
          name: "Some Object",
          fields: {
            title: {
              type: "string",
            },
            description: {
              type: "string",
            },
          },
        },
      )

    expect(objects_setting.value).to eq(
      [{ "title" => "Some title", "description" => "Some description" }],
    )

    objects_setting.value = [{ title: "title 1", description: "description 1" }]

    expect(objects_setting.value).to eq(
      [{ "title" => "title 1", "description" => "description 1" }],
    )
  end
end
