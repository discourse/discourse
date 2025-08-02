# frozen_string_literal: true

RSpec.describe ThemeIndexSerializer do
  fab!(:theme) { Fabricate(:theme, user_selectable: true) }
  fab!(:screenshot_upload) do
    UploadCreator.new(file_from_fixtures("logo.png"), "logo.png").create_for(-1)
  end
  fab!(:screenshot_field) do
    Fabricate(
      :theme_field,
      theme:,
      target_id: Theme.targets[:common],
      name: "screenshot",
      upload_id: screenshot_upload.id,
      type_id: ThemeField.types[:theme_screenshot_upload_var],
    )
  end

  let(:serializer) { ThemeIndexSerializer.new(theme, root: false) }
  let(:json) { serializer.as_json }

  it "includes basic theme attributes" do
    expect(json[:id]).to eq(theme.id)
    expect(json[:name]).to eq(theme.name)
    expect(json[:enabled]).to eq(theme.enabled)
    expect(json[:user_selectable]).to eq(true)
  end

  it "includes screenshot_url attribute" do
    expect(json[:screenshot_url]).to eq(screenshot_upload.url)
  end

  it "includes color_scheme relationship when present" do
    expect(json[:color_scheme]).to eq(nil)

    theme.color_scheme = Fabricate(:color_scheme)
    theme.save!

    new_json = ThemeIndexSerializer.new(theme, root: false).as_json
    expect(new_json[:color_scheme][:id]).to eq(theme.color_scheme.id)
  end

  it "includes remote_theme relationship when present" do
    expect(json[:remote_theme]).to eq(nil)

    remote_theme = RemoteTheme.create!(remote_url: "https://github.com/discourse/sample-theme")
    theme.update!(remote_theme_id: remote_theme.id)

    new_json = ThemeIndexSerializer.new(theme, root: false).as_json
    expect(new_json[:remote_theme][:id]).to eq(remote_theme.id)
  end
end
