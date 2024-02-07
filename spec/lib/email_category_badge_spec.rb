# frozen_string_literal: true

require "category_badge"

RSpec.describe CategoryBadge do
  it "escapes HTML in category names" do
    c = Fabricate(:category, name: "<b>name</b>")

    html = CategoryBadge.html_for(c, inline_style: true)

    expect(html).not_to include("<b>name</b>")
    expect(html).to include("&lt;b&gt;name&lt;/b&gt;")
  end

  it "includes inline color styles" do
    c = Fabricate(:category, color: "123456", text_color: "654321")

    html = CategoryBadge.html_for(c, inline_style: true)

    expect(html).to include("color: #654321;")
    expect(html).to include("background-color: #123456;")
  end
end
