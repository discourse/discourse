# encoding: utf-8

require 'rails_helper'

describe ThemeField do
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

end
