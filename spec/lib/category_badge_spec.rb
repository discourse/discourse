# frozen_string_literal: true

require "category_badge"

RSpec.describe CategoryBadge do
  it "escapes HTML in category names / descriptions" do
    c = Fabricate(:category, name: "<b>name</b>", description: "<b>title</b>")

    html = CategoryBadge.html_for(c)

    expect(html).not_to include("<b>title</b>")
    expect(html).not_to include("<b>name</b>")
    expect(html).to include(ERB::Util.html_escape("<b>name</b>"))
    expect(html).to include("title='title'")
  end

  it "escapes code block contents" do
    c = Fabricate(:category, description: '<code>\' &lt;b id="x"&gt;</code>')
    html = CategoryBadge.html_for(c)

    expect(html).to include("title='&#39; &lt;b id=&quot;x&quot;&gt;'")
  end
end
