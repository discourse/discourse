# frozen_string_literal: true
include ActionView::Helpers::NumberHelper

RSpec.describe Onebox::Engine::TwitterStatusOnebox do
  shared_examples_for "#to_html" do
    it "includes tweet" do
      expect(html).to include(tweet_content)
    end

    # TODO: handle t.co links
    # it "includes link" do
    #   expect(html).to include("http://www.peers.org/action/peers-pledgea")
    # end

    it "gets the correct timestamp" do
      expect(html).to include(timestamp)
    end

    it "includes name" do
      expect(html).to include(full_name)
    end

    it "includes username" do
      expect(html).to include(screen_name)
    end

    it "includes user avatar" do
      expect(html).to include(avatar)
    end

    it "includes twitter link" do
      expect(html).to include(link)
    end

    it "includes twitter likes" do
      expect(html).to include(favorite_count)
    end

    it "includes twitter retweets" do
      expect(html).to include(retweets_count)
    end
  end

  shared_context "with standard tweet info" do
    before do
      @link = "https://twitter.com/MKBHD/status/1625192182859632661"
      @onebox_fixture = "twitterstatus"
    end

    let(:full_name) { "Marques Brownlee" }
    let(:screen_name) { "MKBHD" }
    let(:avatar) { "https://pbs.twimg.com/profile_images/1468001914302390278/B_Xv_8gu_normal.jpg" }
    let(:timestamp) { "5:56 PM - 13 Feb 2023" }
    let(:link) { @link }
    let(:favorite_count) { "47K" }
    let(:retweets_count) { "1.5K" }
  end

  shared_context "with quoted tweet info" do
    before do
      @link = "https://twitter.com/Metallica/status/1128068672289890305"
      @onebox_fixture = "twitterstatus_quoted"

      stub_request(:head, @link)
      stub_request(:get, @link).to_return(status: 200, body: onebox_response(@onebox_fixture))
    end

    let(:full_name) { "Metallica" }
    let(:screen_name) { "Metallica" }
    let(:avatar) { "https://pbs.twimg.com/profile_images/1597280886809952256/gsJvGiqU_normal.jpg" }
    let(:timestamp) { "10:45 PM - 13 May 2019" }
    let(:link) { @link }
    let(:favorite_count) { "1.4K" }
    let(:retweets_count) { "170" }
  end

  shared_context "with featured image info" do
    before do
      @link = "https://twitter.com/codinghorror/status/1409351083177046020"
      @onebox_fixture = "twitterstatus_featured_image"

      stub_request(:get, @link.downcase).to_return(
        status: 200,
        body: onebox_response(@onebox_fixture),
      )
    end

    let(:full_name) { "Jeff Atwood" }
    let(:screen_name) { "codinghorror" }
    let(:avatar) { "https://pbs.twimg.com/profile_images/1517287320235298816/Qx-O6UCY_normal.jpg" }
    let(:timestamp) { "3:02 PM - 27 Jun 2021" }
    let(:link) { @link }
    let(:favorite_count) { "90" }
    let(:retweets_count) { "5" }
  end

  shared_examples "includes quoted tweet data" do
    it "includes quoted tweet" do
      expect(html).to include(
        "If you bought a ticket for tonight’s @Metallica show at Stade de France, you have helped",
      )
    end

    it "includes quoted tweet name" do
      expect(html).to include("All Within My Hands Foundation")
    end

    it "includes quoted username" do
      expect(html).to include("AWMHFoundation")
    end

    it "includes quoted tweet link" do
      expect(html).to include("https://twitter.com/AWMHFoundation/status/1127646016931487744")
    end
  end

  context "without twitter client" do
    let(:link) { "https://twitter.com/discourse/status/1428031057186627589" }
    let(:html) { described_class.new(link).to_html }

    it "does match the url" do
      onebox = Onebox::Matcher.new(link, { allowed_iframe_regexes: [/.*/] }).oneboxed
      expect(onebox).to be(described_class)
    end

    it "logs a warn message if rate limited" do
      SiteSetting.twitter_consumer_key = "twitter_consumer_key"
      SiteSetting.twitter_consumer_secret = "twitter_consumer_secret"

      stub_request(:post, "https://api.twitter.com/oauth2/token").to_return(
        status: 200,
        body: "{\"access_token\":\"token\"}",
        headers: {
        },
      )

      stub_request(
        :get,
        "https://api.twitter.com/2/tweets/1428031057186627589?tweet.fields=id,author_id,text,created_at,entities,referenced_tweets,public_metrics&user.fields=id,name,username,profile_image_url&media.fields=type,height,width,variants,preview_image_url,url&expansions=attachments.media_keys,referenced_tweets.id.author_id",
      ).to_return(status: 429, body: "{}", headers: {})

      Rails.logger.expects(:warn).with(regexp_matches(/rate limit/)).at_least_once

      expect(html).to eq("")
    end

    describe "it resorts to html open graph tags" do
      context "with a standard tweet" do
        let(:tweet_content) { "I've never played Minecraft" }
        include_context "with standard tweet info"
        before { @onebox_fixture = "twitterstatus_noclient" }
        include_context "with engines"

        let(:avatar) do
          "https://pbs.twimg.com/profile_images/1468001914302390278/B_Xv_8gu_200x200.jpg"
        end
        let(:timestamp) { "" }
        let(:favorite_count) { "" }
        let(:retweets_count) { "" }

        it_behaves_like "an engine"
        it_behaves_like "#to_html"
      end
    end
  end

  describe "when the domain is x.com" do
    before do
      @link = "https://x.com/MKBHD/status/1625192182859632661"
      @onebox_fixture = "xstatus_noclient"
    end
    include_context "with engines"

    let(:tweet_content) { "I&#39;ve never played Minecraft" }
    let(:full_name) { "Marques Brownlee" }
    let(:screen_name) { "MKBHD" }
    let(:avatar) { "" }
    let(:timestamp) { "" }
    let(:favorite_count) { "" }
    let(:retweets_count) { "" }

    it_behaves_like "an engine"
    it_behaves_like "#to_html"
  end

  context "with twitter client" do
    before do
      @twitter_client =
        stub(
          "TwitterClient",
          status: api_response,
          prettify_tweet: tweet_content,
          twitter_credentials_missing?: false,
        )

      @previous_options = Onebox.options.to_h
      Onebox.options = { twitter_client: @twitter_client }
    end

    after { Onebox.options = @previous_options }

    context "with a standard tweet" do
      let(:tweet_content) { "I've never played Minecraft" }

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
            text: "I've never played Minecraft",
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

      include_context "with standard tweet info"
      include_context "with engines"

      it_behaves_like "an engine"
      it_behaves_like "#to_html"
    end

    context "with quoted tweet" do
      let(:tweet_content) do
        "Thank you to everyone who came out for <a href='https://twitter.com/search?q=%23MetInParis' target='_blank'>#MetInParis</a> last night for helping us support <a href='https://twitter.com/EMMAUSolidarite' target='_blank'>@EMMAUSolidarite</a> &amp; <a href='https://twitter.com/PompiersParis' target='_blank'>@PompiersParis</a>. <a href='https://twitter.com/search?q=%23AWMH' target='_blank'>#AWMH</a> <a href='https://twitter.com/search?q=%23MetalicaGivesBack' target='_blank'>#MetalicaGivesBack</a> <a href=\"https://t.co/gLtZSdDFmN\" target=\"_blank\">https://t.co/gLtZSdDFmN</a>"
      end

      let(:api_response) do
        {
          data: {
            text:
              "Thank you to everyone who came out for #MetInParis last night for helping us support @EMMAUSolidarite &amp; @PompiersParis. #AWMH #MetalicaGivesBack https://t.co/gLtZSdDFmN",
            edit_history_tweet_ids: ["1128068672289890305"],
            entities: {
              mentions: [
                { start: 85, end: 101, username: "EMMAUSolidarite", id: "2912493406" },
                { start: 108, end: 122, username: "PompiersParis", id: "1342191438" },
              ],
              urls: [
                {
                  start: 149,
                  end: 172,
                  url: "https://t.co/gLtZSdDFmN",
                  expanded_url: "https://twitter.com/AWMHFoundation/status/1127646016931487744",
                  display_url: "twitter.com/AWMHFoundation…",
                },
              ],
              hashtags: [
                { start: 39, end: 50, tag: "MetInParis" },
                { start: 124, end: 129, tag: "AWMH" },
                { start: 130, end: 148, tag: "MetalicaGivesBack" },
              ],
              annotations: [
                {
                  start: 40,
                  end: 49,
                  probability: 0.6012,
                  type: "Other",
                  normalized_text: "MetInParis",
                },
                {
                  start: 125,
                  end: 128,
                  probability: 0.5884,
                  type: "Other",
                  normalized_text: "AWMH",
                },
                {
                  start: 131,
                  end: 147,
                  probability: 0.6366,
                  type: "Other",
                  normalized_text: "MetalicaGivesBack",
                },
              ],
            },
            id: "1128068672289890305",
            referenced_tweets: [{ type: "quoted", id: "1127646016931487744" }],
            created_at: "2019-05-13T22:45:04.000Z",
            public_metrics: {
              retweet_count: 171,
              reply_count: 21,
              like_count: 1424,
              quote_count: 0,
              bookmark_count: 2,
              impression_count: 0,
            },
            author_id: "238475531",
          },
          includes: {
            users: [
              {
                profile_image_url:
                  "https://pbs.twimg.com/profile_images/1597280886809952256/gsJvGiqU_normal.jpg",
                name: "Metallica",
                id: "238475531",
                username: "Metallica",
              },
              {
                profile_image_url:
                  "https://pbs.twimg.com/profile_images/935181032185241600/D8FoOIRJ_normal.jpg",
                name: "All Within My Hands Foundation",
                id: "886959980254871552",
                username: "AWMHFoundation",
              },
            ],
            tweets: [
              {
                text:
                  "If you bought a ticket for tonight’s @Metallica show at Stade de France, you have helped contribute to @EMMAUSolidarite &amp; @PompiersParis. #MetallicaGivesBack #AWMH #MetInParis https://t.co/wlUtDQbQEK",
                edit_history_tweet_ids: ["1127646016931487744"],
                entities: {
                  mentions: [
                    { start: 37, end: 47, username: "Metallica", id: "238475531" },
                    { start: 103, end: 119, username: "EMMAUSolidarite", id: "2912493406" },
                    { start: 126, end: 140, username: "PompiersParis", id: "1342191438" },
                  ],
                  urls: [
                    {
                      start: 180,
                      end: 203,
                      url: "https://t.co/wlUtDQbQEK",
                      expanded_url:
                        "https://twitter.com/AWMHFoundation/status/1127646016931487744/photo/1",
                      display_url: "pic.twitter.com/wlUtDQbQEK",
                      media_key: "3_1127645176183250944",
                    },
                    {
                      start: 180,
                      end: 203,
                      url: "https://t.co/wlUtDQbQEK",
                      expanded_url:
                        "https://twitter.com/AWMHFoundation/status/1127646016931487744/photo/1",
                      display_url: "pic.twitter.com/wlUtDQbQEK",
                      media_key: "3_1127645195384774657",
                    },
                  ],
                  hashtags: [
                    { start: 142, end: 161, tag: "MetallicaGivesBack" },
                    { start: 162, end: 167, tag: "AWMH" },
                    { start: 168, end: 179, tag: "MetInParis" },
                  ],
                  annotations: [
                    {
                      start: 56,
                      end: 70,
                      probability: 0.7845,
                      type: "Place",
                      normalized_text: "Stade de France",
                    },
                    {
                      start: 143,
                      end: 160,
                      probability: 0.5569,
                      type: "Organization",
                      normalized_text: "MetallicaGivesBack",
                    },
                    {
                      start: 163,
                      end: 166,
                      probability: 0.4496,
                      type: "Other",
                      normalized_text: "AWMH",
                    },
                    {
                      start: 169,
                      end: 178,
                      probability: 0.3784,
                      type: "Place",
                      normalized_text: "MetInParis",
                    },
                  ],
                },
                id: "1127646016931487744",
                created_at: "2019-05-12T18:45:35.000Z",
                attachments: {
                  media_keys: %w[3_1127645176183250944 3_1127645195384774657],
                },
                public_metrics: {
                  retweet_count: 34,
                  reply_count: 5,
                  like_count: 241,
                  quote_count: 9,
                  bookmark_count: 0,
                  impression_count: 0,
                },
                author_id: "886959980254871552",
              },
            ],
          },
        }
      end

      include_context "with quoted tweet info"
      include_context "with engines"

      it_behaves_like "an engine"
      it_behaves_like "#to_html"
      it_behaves_like "includes quoted tweet data"
    end
  end
end
