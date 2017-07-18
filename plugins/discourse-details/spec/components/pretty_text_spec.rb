require 'rails_helper'
require 'pretty_text'

describe PrettyText do

  it "supports details tag" do
    cooked_html = "<details><summary>foo</summary>bar</details>"
    expect(PrettyText.cook("<details><summary>foo</summary>bar</details>")).to match_html(cooked_html)

    cooked_html = <<~HTML
      <details>
      <summary>
      foo</summary>
      <p>bar</p>
      </details>
    HTML
    expect(PrettyText.cook("[details=foo]\nbar\n[/details]")).to eq(cooked_html.strip)
  end

end
