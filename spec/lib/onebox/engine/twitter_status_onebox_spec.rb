# frozen_string_literal: true

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

    it "gets the correct timestamp" do
      expect(onebox.send(:timestamp)).to eq("6:59 PM - 1 Aug 2013")
    end

    it "includes name" do
      expect(html).to include("Vyki Englert")
    end

    it "includes username" do
      expect(html).to include("vyki_e")
    end

    it "includes user avatar" do
      expect(html).to include("732349210264133632/RTNgZLrm_400x400.jpg")
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
      allow(@twitter_client).to receive("status")
        .and_return mockTwitterAPIReponse

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

  def mockTwitterAPIReponse
    {
      created_at: "Fri Aug 02 01:59:30 +0000 2013",
      id: 363116819147538400,
      id_str: "363116819147538433",
      text: "I'm a sucker for pledges. @Peers Pledge #sharingeconomy http://t.co/T4Sc47KAzh",
      truncated: false,
      entities: {
        hashtags: [
           {
            text: "sharingeconomy",
            indices: [
              41,
              56
            ]
          }
        ],
        symbols: [],
        user_mentions: [
           {
            screen_name: "peers",
            name: "Peers",
            id: 1428357889,
            id_str: "1428357889",
            indices: [
              27,
              33
            ]
          }
        ],
        urls: [
           {
            url: "http://t.co/T4Sc47KAzh",
            expanded_url: "http://www.peers.org/action/peers-pledgea/",
            display_url: "peers.org/action/peers-p…",
            indices: [
              57,
              79
            ]
          }
        ]
      },
      source: "<a href=\"https://dev.twitter.com/docs/tfw\" rel=\"nofollow\">Twitter for Websites</a>",
      in_reply_to_status_id: nil,
      in_reply_to_status_id_str: nil,
      in_reply_to_user_id: nil,
      in_reply_to_user_id_str: nil,
      in_reply_to_screen_name: nil,
      user: {
        id: 1087064150,
        id_str: "1087064150",
        name: "Vyki Englert",
        screen_name: "vyki_e",
        location: "Los Angeles, CA",
        description: "Rides bikes, writes code, likes maps. @CompilerLA / @CityGrows / Brigade Captain @HackforLA",
        url: "http://t.co/YCAP3asRG1",
        entities: {
          url: {
            urls: [
               {
                url: "http://t.co/YCAP3asRG1",
                expanded_url: "http://www.compiler.la",
                display_url: "compiler.la",
                indices: [
                  0,
                  22
                ]
              }
            ]
          },
          description: {
            urls: []
          }
        },
        protected: false,
        followers_count: 1128,
        friends_count: 2244,
        listed_count: 83,
        created_at: "Sun Jan 13 19:53:00 +0000 2013",
        favourites_count: 2928,
        utc_offset: -25200,
        time_zone: "Pacific Time (US & Canada)",
        geo_enabled: true,
        verified: false,
        statuses_count: 3295,
        lang: "en",
        contributors_enabled: false,
        is_translator: false,
        is_translation_enabled: false,
        profile_background_color: "ACDED6",
        profile_background_image_url: "http://abs.twimg.com/images/themes/theme18/bg.gif",
        profile_background_image_url_https: "https://abs.twimg.com/images/themes/theme18/bg.gif",
        profile_background_tile: false,
        profile_image_url: "http://pbs.twimg.com/profile_images/732349210264133632/RTNgZLrm_normal.jpg",
        profile_image_url_https: "https://pbs.twimg.com/profile_images/732349210264133632/RTNgZLrm_normal.jpg",
        profile_banner_url: "https://pbs.twimg.com/profile_banners/1087064150/1424315468",
        profile_link_color: "4E99D1",
        profile_sidebar_border_color: "EEEEEE",
        profile_sidebar_fill_color: "F6F6F6",
        profile_text_color: "333333",
        profile_use_background_image: true,
        has_extended_profile: false,
        default_profile: false,
        default_profile_image: false,
        following: false,
        follow_request_sent: false,
        notifications: false
      },
      geo: nil,
      coordinates: nil,
      place: nil,
      contributors: nil,
      is_quote_status: false,
      retweet_count: 0,
      favorite_count: 0,
      favorited: false,
      retweeted: false,
      possibly_sensitive: false,
      possibly_sensitive_appealable: false,
      lang: "en"
    }
  end
end
