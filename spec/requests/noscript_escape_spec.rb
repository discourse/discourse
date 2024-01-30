# frozen_string_literal: true
RSpec.describe "escaping of noscript content" do
  def noscript_content
    # Browsers do not parse the contents of noscript tags - they just look for the next string matching `</noscript>`
    # Can't use nokogiri because it parses documents with the 'scripting flag' disabled, and therefore parses html inside noscript tags
    noscript_content = response.body.scan(%r{<noscript.*?>(.*?)</noscript>}m).join("\n")
  end

  it "does not affect normal content" do
    post = Fabricate(:post, raw: 'This is a post with an image <img alt="<Look at this!>">')
    get post.url

    expect(noscript_content).to include('<img alt="<Look at this!>">')
  end

  it "escapes noscript in attribute" do
    post =
      Fabricate(
        :post,
        raw: 'This is a post with an image <img alt="</noscript>"> containing a noscript end tag',
      )
    get post.url

    expect(noscript_content).to include('<img alt="&lt;/noscript>">')
  end

  it "escapes noscript with trailing whitespace" do
    post =
      Fabricate(
        :post,
        raw: 'This is a post with an image <img alt="</noscript  >"> containing a noscript end tag',
      )
    get post.url

    expect(noscript_content).to include('<img alt="&lt;/noscript  >">')
  end

  it "escapes noscript with leading whitespace" do
    # The spec doesn't accept closing tags with leading whitespace. Browsers follow that, but some other parsers are more relaxed so we escape anyway
    post =
      Fabricate(
        :post,
        raw: 'This is a post with an image <img alt="</  noscript>"> containing a noscript end tag',
      )
    get post.url

    expect(noscript_content).to include('<img alt="&lt;/  noscript>">')
  end
end
