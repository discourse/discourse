# frozen_string_literal: true

require "email_category_badge"

RSpec.describe EmailCategoryBadge do
  it "escapes HTML in category names" do
    c = Fabricate(:category, name: "<b>name</b>")

    html = EmailCategoryBadge.html_for(c)

    expect(html).not_to include("<b>name</b>")
    expect(html).to include(ERB::Util.html_escape("<b>name</b>"))
  end

  it "includes inline color styles" do
    c = Fabricate(:category, color: "123456", text_color: "654321")
    html = EmailCategoryBadge.html_for(c)

    expect(html).to have_selector("span[data-category-id]", style: /color: #654321;/)

    expect(html).to have_selector(
      "span[data-category-id] > span > span",
      style: "background-color: #123456;",
    )
  end
end