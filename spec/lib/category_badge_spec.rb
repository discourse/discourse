# frozen_string_literal: true

require "category_badge"

RSpec.describe CategoryBadge do
  it "escapes HTML in category names" do
    c = Fabricate(:category, name: "<b>name</b>")

    html = CategoryBadge.html_for(c)

    expect(html).not_to include("<b>name</b>")
    expect(html).to include("&lt;b&gt;name&lt;/b&gt;")
  end

  it "does not expose the category description as a tooltip" do
    c = Fabricate(:category, description: "a description")

    html = CategoryBadge.html_for(c)

    expect(html).not_to include("title=")
    expect(html).not_to include("a description")
  end

  it "includes color vars" do
    c = Fabricate(:category, color: "123456", text_color: "654321")
    html = CategoryBadge.html_for(c)

    expect(html).to have_tag(
      "span[data-category-id]",
      with: {
        style: "--category-badge-color: #123456; --category-badge-text-color: #654321;",
      },
    )
  end

  it "includes inline color style when inline_style is true" do
    c = Fabricate(:category, color: "123456")

    html = CategoryBadge.html_for(c, inline_style: true)

    expect(html).to include("background-color: #123456;")
  end
end
