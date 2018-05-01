# encoding: utf-8

require 'rails_helper'

describe ThemeField do
  after(:all) do
    ThemeField.destroy_all
  end

  it "correctly generates errors for transpiled js" do
    html = <<HTML
<script type="text/discourse-plugin" version="0.8">
   badJavaScript(;
</script>
HTML

    field = ThemeField.create!(theme_id: 1, target_id: 0, name: "header", value: html)
    expect(field.error).not_to eq(nil)

    field.update!(value: '')
    expect(field.error).to eq(nil)
  end

  it "allows us to use theme settings in handlebars templates" do
    html = <<HTML
<script type='text/x-handlebars' data-template-name='my-template'>
    <div class="testing-div">{{themeSettings.string_setting}}</div>
</script>
HTML

    ThemeField.create!(theme_id: 1, target_id: 3, name: "yaml", value: "string_setting: \"test text \\\" 123!\"")
    baked_value = ThemeField.create!(theme_id: 1, target_id: 0, name: "head_tag", value: html).value_baked

    expect(baked_value).to include("testing-div")
    expect(baked_value).to include("theme-setting-injector")
    expect(baked_value).to include("string_setting")
    expect(baked_value).to include("test text \\\\\\\\u0022 123!")
  end

  it "correctly generates errors for transpiled css" do
    css = "body {"
    field = ThemeField.create!(theme_id: 1, target_id: 0, name: "scss", value: css)
    field.reload
    expect(field.error).not_to eq(nil)
    field.value = "body {color: blue};"
    field.save!
    field.reload

    expect(field.error).to eq(nil)
  end

  def create_upload_theme_field!(name)
    ThemeField.create!(
      theme_id: 1,
      target_id: 0,
      value: "",
      type_id: ThemeField.types[:theme_upload_var],
      name: name,
    )
  end

  it "ensures we don't use invalid SCSS variable names" do
    expect { create_upload_theme_field!("42") }.to raise_error(ActiveRecord::RecordInvalid)
    expect { create_upload_theme_field!("a42") }.not_to raise_error
  end

  def get_fixture(type)
    File.read("#{Rails.root}/spec/fixtures/theme_settings/#{type}_settings.yaml")
  end

  def create_yaml_field(value)
    field = ThemeField.create!(theme_id: 1, target_id: Theme.targets[:settings], name: "yaml", value: value)
    field.reload
    field
  end

  let(:key) { "themes.settings_errors" }

  it "generates errors for bad YAML" do
    yaml = "invalid_setting 5"
    field = create_yaml_field(yaml)
    expect(field.error).to eq(I18n.t("#{key}.invalid_yaml"))

    field.value = "valid_setting: true"
    field.save!
    field.reload
    expect(field.error).to eq(nil)
  end

  it "generates errors when default value's type doesn't match setting type" do
    field = create_yaml_field(get_fixture("invalid"))
    expect(field.error).to include(I18n.t("#{key}.default_not_match_type", name: "no_match_setting"))
  end

  it "generates errors when no default value is passed" do
    field = create_yaml_field(get_fixture("invalid"))
    expect(field.error).to include(I18n.t("#{key}.default_value_missing", name: "no_default_setting"))
  end

  it "generates errors when invalid type is passed" do
    field = create_yaml_field(get_fixture("invalid"))
    expect(field.error).to include(I18n.t("#{key}.data_type_not_a_number", name: "invalid_type_setting"))
  end

  it "generates errors when default value is not within allowed range" do
    field = create_yaml_field(get_fixture("invalid"))
    expect(field.error).to include(I18n.t("#{key}.default_out_range", name: "default_out_of_range"))
    expect(field.error).to include(I18n.t("#{key}.default_out_range", name: "string_default_out_of_range"))
  end

  it "works correctly when valid yaml is provided" do
    field = create_yaml_field(get_fixture("valid"))
    expect(field.error).to be_nil
  end
end
