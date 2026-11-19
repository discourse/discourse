# frozen_string_literal: true

describe "Code block line numbers" do
  let(:lines) { (1..70).map { |number| "  echo #{number}  " } }
  let(:post) { Fabricate(:post, raw: "```bash\n#{lines.join("\n")}\n```") }

  it "does not show a gutter by default" do
    visit post.topic.relative_url

    expect(page).to have_css(".cooked pre > code")
    expect(page).to have_no_css(".codeblock-line-numbers")
  end

  it "keeps the gutter aligned and synchronized without changing the code text" do
    SiteSetting.show_codeblock_line_numbers = true
    visit post.topic.relative_url

    expect(page).to have_css(".codeblock-line-numbers[aria-hidden='true']")
    result = page.evaluate_script <<~'JS'
      (() => {
        const code = document.querySelector(".codeblock-numbered > code");
        const gutter = document.querySelector(".codeblock-line-numbers");
        code.scrollTop = 160;
        code.dispatchEvent(new Event("scroll"));
        return {
          codeText: code.innerText,
          numbers: gutter.textContent.split("\n").map(Number),
          codeScroll: code.scrollTop,
          gutterScroll: gutter.scrollTop,
          lineHeightsMatch: getComputedStyle(code).lineHeight === getComputedStyle(gutter).lineHeight,
        };
      })()
    JS

    expect(result["codeText"]).to eq("#{lines.join("\n")}\n")
    expect(result["numbers"]).to eq((1..70).to_a)
    expect(result["codeScroll"]).to be > 0
    expect(result["gutterScroll"]).to eq(result["codeScroll"])
    expect(result["lineHeightsMatch"]).to eq(true)
  end
end
