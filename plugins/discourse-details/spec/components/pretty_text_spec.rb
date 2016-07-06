require 'rails_helper'
require 'pretty_text'

describe PrettyText do

  it "supports details tag" do
    cooked_html = "<details><summary>foo</summary>\n\n<p>bar</p>\n\n<p></p></details>"
    expect(PrettyText.cook("<details><summary>foo</summary>bar</details>")).to match_html(cooked_html)
    expect(PrettyText.cook("[details=foo]bar[/details]")).to match_html(cooked_html)
  end

end
