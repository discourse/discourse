# frozen_string_literal: true

RSpec.describe Onebox::Engine::RedditMediaOnebox do
  let(:link) { "https://www.reddit.com/r/colors/comments/b4d5xm/literally_nothing_black_edition" }
  let(:html) { described_class.new(link).to_html }

  before do
    stub_request(:head, "#{link}/").to_return(status: 200)
    stub_request(:get, link).to_return(status: 200, body: onebox_response("reddit_image"))
    stub_request(:get, "#{link}/").to_return(status: 200, body: onebox_response("reddit_image"))
  end

  it "includes title" do
    expect(html).to include(
      '<a href="https://www.reddit.com/r/colors/comments/b4d5xm/literally_nothing_black_edition/" target="_blank" rel="nofollow ugc noopener">reddit</a>',
    )
  end

  it "includes image" do
    expect(html).to include("https://preview.redd.it/vsg59iw0srn21.jpg")
  end

  it "includes description" do
    expect(html).to include("Literally nothing black edition")
  end

  describe ".===" do
    it "matches valid Reddit URL" do
      valid_url = URI(link)
      expect(described_class === valid_url).to eq(true)
    end

    it "does not match invalid Reddit URL" do
      invalid_url = URI("https://www.reddit.com.somedomain.com/r/colors/comments/b4d5xm/")
      expect(described_class === invalid_url).to eq(false)
    end
  end
end
