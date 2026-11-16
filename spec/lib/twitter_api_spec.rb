# frozen_string_literal: true

RSpec.describe TwitterApi do
  describe ".prettify_tweet" do
    it "renders the text and expanded URLs as text" do
      tweet = {
        data: {
          text: "&lt;b&gt;hi&lt;/b&gt; https://t.co/abc",
          entities: {
            urls: [
              {
                url: "https://t.co/abc",
                expanded_url: "https://example.com/?q='b",
                display_url: "example.com/?q='b",
              },
            ],
          },
        },
      }

      fragment = Nokogiri::HTML5.fragment(described_class.prettify_tweet(tweet))

      expect(fragment.text).to eq("<b>hi</b> example.com/?q='b")
      expect(fragment.at_css("a")["href"]).to eq("https://example.com/?q='b")
    end
  end

  describe ".link_handles_in" do
    it "correctly replaces handles" do
      expect(TwitterApi.send(:link_handles_in, "@foo @foobar")).to match_html <<~HTML
        <a href='https://twitter.com/foo' target='_blank'>@foo</a> <a href='https://twitter.com/foobar' target='_blank'>@foobar</a>
      HTML
    end
  end

  describe ".link_hashtags_in" do
    it "correctly replaces hashtags" do
      expect(TwitterApi.send(:link_hashtags_in, "#foo #foobar")).to match_html <<~HTML
        <a href='https://twitter.com/search?q=%23foo' target='_blank'>#foo</a> <a href='https://twitter.com/search?q=%23foobar' target='_blank'>#foobar</a>
      HTML
    end
  end
end
