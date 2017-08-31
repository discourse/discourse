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

end
