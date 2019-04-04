require "spec_helper"

describe Onebox::Engine::RedditImageOnebox do
  let(:link) { "https://www.reddit.com/r/colors/comments/b4d5xm/literally_nothing_black_edition" }
  let(:html) { described_class.new(link).to_html }

  before do
    fake(link, response("reddit_image"))
  end

  it "includes title" do
    puts response("reddit_image")
    expect(html).to include('<a href="https://www.reddit.com/r/colors/comments/b4d5xm/literally_nothing_black_edition/" target="_blank" rel="nofollow noopener">reddit</a>')
  end

  it "includes image" do
    expect(html).to include("https://preview.redd.it/vsg59iw0srn21.jpg")
  end

  it "includes description" do
    expect(html).to include("Literally nothing black edition")
  end
end
