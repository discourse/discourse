# frozen_string_literal: true

RSpec.describe TwitterApi do
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

  describe ".prettify_tweet" do
    let(:api_response) do
      {
        data: {
          edit_history_tweet_ids: ["1625192182859632661"],
          created_at: "2023-02-13T17:56:25.000Z",
          author_id: "29873662",
          public_metrics: {
            retweet_count: 1460,
            reply_count: 2734,
            like_count: 46_756,
            quote_count: 477,
            bookmark_count: 168,
            impression_count: 4_017_878,
          },
          text:
            "Shoutout to @discourse for making online communities thrive! Just launched a new plugin—check it out here: https://example.com/discourse-plugin 🔥 #forum",
          entities: {
            annotations: [
              {
                start: 18,
                end: 26,
                probability: 0.9807,
                type: "Other",
                normalized_text: "Minecraft",
              },
            ],
          },
          id: "1625192182859632661",
        },
        includes: {
          users: [
            {
              name: "Marques Brownlee",
              id: "29873662",
              profile_image_url:
                "https://pbs.twimg.com/profile_images/1468001914302390278/B_Xv_8gu_normal.jpg",
              username: "MKBHD",
            },
          ],
        },
      }
    end

    it { expect(described_class.prettify_tweet(api_response)).to eq(<<~HTML.strip) }
        Shoutout to <a href="https://twitter.com/discourse" target="_blank" rel="noopener nofollow ugc">@discourse</a> for making online communities thrive! Just launched a new plugin—check it out here: <a href="https://example.com/discourse-plugin" rel="noopener nofollow ugc">https://example.com/discourse-plugin</a> 🔥 <a href="https://twitter.com/search?q=%23forum" target="_blank" rel="noopener nofollow ugc">#forum</a>
      HTML
  end
end
