require "spec_helper"

describe Onebox::Engine::TwitterStatusOnebox do
  before(:all) do
    @link = "https://twitter.com/vyki_e/status/363116819147538433"
  end

  shared_examples_for "#to_html" do
    it "includes tweet" do
      expect(html).to include("I'm a sucker for pledges.")
    end

    # TODO: handle t.co links
    # it "includes link" do
    #   expect(html).to include("http://www.peers.org/action/peers-pledgea")
    # end

    # TODO: weird spec..
    # it "includes timestamp" do
    #   expect(html).to include("6:59 PM - 1 Aug 13")
    # end

    it "includes name" do
      expect(html).to include("Vyki Englert")
    end

    it "includes username" do
      expect(html).to include("vyki_e")
    end

    it "includes user avatar" do
      expect(html).to include("568244395007168512/qQVXa2Ql_normal.jpeg")
    end
  end

  context "with html" do
    include_context "engines"
    it_behaves_like "an engine"
    it_behaves_like "#to_html"
  end

  context "with twitter client" do
    before(:each) do
      @twitter_client = double("TwitterClient")
      allow(@twitter_client).to receive("status") do
        {
          created_at: "Fri Aug 02 01:59:30 +0000 2013",
          id: 363_116_819_147_538_433,
          id_str: "363116819147538433",
          text:
            "I'm a sucker for pledges.  @Peers Pledge #sharingeconomy http://t.co/T4Sc47KAzh",
          source:
            "<a href=\"http://twitter.com/tweetbutton\" rel=\"nofollow\">Tweet Button</a>",
          user:
            { id: 1_087_064_150,
              id_str: "1087064150",
              name: "Vyki Englert",
              screen_name: "vyki_e",
              location: "Los Angeles, CA",
              description: "I am woman, hear me #RoR.",
              url: "http://t.co/umZG76wmv2",
              protected: false,
              followers_count: 249,
              friends_count: 907,
              listed_count: 6,
              created_at: "Sun Jan 13 19:53:00 +0000 2013",
              favourites_count: 506,
              statuses_count: 926,
              lang: "en",
              contributors_enabled: false,
              is_translator: false,
              profile_image_url:
                "http://pbs.twimg.com/profile_images/568244395007168512/qQVXa2Ql_normal.jpeg",
              profile_image_url_https:
                "https://pbs.twimg.com/profile_images/568244395007168512/qQVXa2Ql_normal.jpeg",
              following: true,
              follow_request_sent: false,
              notifications: nil },
          geo: nil,
          coordinates: nil,
          place: nil,
          contributors: nil,
          retweet_count: 0,
          favorite_count: 0,
          favorited: false,
          retweeted: false,
          possibly_sensitive: false,
          lang: "en"
        }
      end
      allow(@twitter_client).to receive("prettify_tweet") do
        "I'm a sucker for pledges.  <a href='https://twitter.com/Peers' target='_blank'>@Peers</a> Pledge <a href='https://twitter.com/search?q=%23sharingeconomy' target='_blank'>#sharingeconomy</a> <a target='_blank' href='http://www.peers.org/action/peers-pledgea/'>peers.org/action/peers-p…</a>"
      end
      allow(@twitter_client).to receive("twitter_credentials_missing?") do
        false
      end
      Onebox.options = { twitter_client: @twitter_client }
    end

    after(:each) do
      Onebox.options = { twitter_client: nil }
    end

    include_context "engines"
    it_behaves_like "an engine"
    it_behaves_like "#to_html"
  end
end
