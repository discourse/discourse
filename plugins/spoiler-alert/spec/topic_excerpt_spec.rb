# frozen_string_literal: true

describe PrettyText do
  it "should remove spoilers from excerpts" do
    expect(
      PrettyText.excerpt("<div class='spoiler'><img src='http://cnn.com/a.gif'></div>", 100),
    ).to match_html ""
    expect(PrettyText.excerpt("<span class='spoiler'>spoiler</span>", 100)).to match_html ""
    expect(
      PrettyText.excerpt("Inline text <span class='spoiler'>spoiler</span> after spoiler", 100),
    ).to match_html "Inline text after spoiler"
  end
end
