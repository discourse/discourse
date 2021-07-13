# frozen_string_literal: true

require "rails_helper"

describe Onebox::Engine::TwitterStatusOnebox do
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

  shared_context "standard tweet info" do
    before do
      @link = "https://twitter.com/vyki_e/status/363116819147538433"
      @onebox_fixture = "twitterstatus"
    end

    let(:full_name) { "Vyki Englert" }
    let(:screen_name) { "vyki_e" }
    let(:avatar) { "732349210264133632/RTNgZLrm_400x400.jpg" }
    let(:timestamp) { "6:59 PM - 1 Aug 2013" }
    let(:link) { @link }
    let(:favorite_count) { "0" }
    let(:retweets_count) { "0" }
  end

  shared_context "quoted tweet info" do
    before do
      @link = "https://twitter.com/metallica/status/1128068672289890305"
      @onebox_fixture = "twitterstatus_quoted"

      stub_request(:get, @link.downcase).to_return(status: 200, body: onebox_response(@onebox_fixture))
    end

    let(:full_name) { "Metallica" }
    let(:screen_name) { "Metallica" }
    let(:avatar) { "profile_images/766360293953802240/kt0hiSmv_400x400.jpg" }
    let(:timestamp) { "10:45 PM - 13 May 2019" }
    let(:link) { @link }
    let(:favorite_count) { "1.7K" }
    let(:retweets_count) { "201" }
  end

  shared_context "featured image info" do
    before do
      @link = "https://twitter.com/codinghorror/status/1409351083177046020"
      @onebox_fixture = "twitterstatus_featured_image"

      stub_request(:get, @link.downcase).to_return(status: 200, body: onebox_response(@onebox_fixture))
    end

    let(:full_name) { "Jeff Atwood" }
    let(:screen_name) { "codinghorror" }
    let(:avatar) { "" }
    let(:timestamp) { "3:02 PM - 27 Jun 2021" }
    let(:link) { @link }
    let(:favorite_count) { "90" }
    let(:retweets_count) { "0" }
  end

  shared_examples "includes quoted tweet data" do
    it 'includes quoted tweet' do
      expect(html).to include("If you bought a ticket for tonight’s @Metallica show at Stade de France, you have helped")
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

  context "with html" do
    context "with a standard tweet" do
      let(:tweet_content) { "I'm a sucker for pledges." }

      include_context "standard tweet info"
      include_context "engines"

      it_behaves_like "an engine"
      it_behaves_like "#to_html"
    end

    context "with a quoted tweet" do
      let(:tweet_content) do
        "Thank you to everyone who came out for #MetInParis last night for helping us support @EMMAUSolidarite &amp;"
      end

      include_context "quoted tweet info"
      include_context "engines"

      it_behaves_like "an engine"
      it_behaves_like '#to_html'
      it_behaves_like "includes quoted tweet data"
    end

    context "with a featured image tweet" do
      let(:tweet_content) do
        "My first text message from my child! A moment that shall live on in infamy!"
      end

      include_context "featured image info"
      include_context "engines"

      it_behaves_like "an engine"
      it_behaves_like '#to_html'
    end
  end

  context "with twitter client" do
    before do
      @twitter_client = stub("TwitterClient",
        status: api_response,
        prettify_tweet: tweet_content,
        twitter_credentials_missing?: false,
        prettify_number: favorite_count
      )

      @previous_options = Onebox.options.to_h
      Onebox.options = { twitter_client: @twitter_client }
    end

    after do
      Onebox.options = @previous_options
    end

    context "with a standard tweet" do
      let(:tweet_content) do
        "I'm a sucker for pledges.  <a href='https://twitter.com/Peers' target='_blank'>@Peers</a> Pledge <a href='https://twitter.com/search?q=%23sharingeconomy' target='_blank'>#sharingeconomy</a> <a target='_blank' href='http://www.peers.org/action/peers-pledgea/'>peers.org/action/peers-p…</a>"
      end

      let(:api_response) do
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

      include_context "standard tweet info"
      include_context "engines"

      it_behaves_like "an engine"
      it_behaves_like "#to_html"
    end

    context "with quoted tweet" do
      let(:tweet_content) do
        "Thank you to everyone who came out for <a href='https://twitter.com/search?q=%23MetInParis' target='_blank'>#MetInParis</a> last night for helping us support <a href='https://twitter.com/EMMAUSolidarite' target='_blank'>@EMMAUSolidarite</a> &amp; <a href='https://twitter.com/PompiersParis' target='_blank'>@PompiersParis</a>. <a href='https://twitter.com/search?q=%23AWMH' target='_blank'>#AWMH</a> <a href='https://twitter.com/search?q=%23MetalicaGivesBack' target='_blank'>#MetalicaGivesBack</a> <a href=\"https://t.co/gLtZSdDFmN\" target=\"_blank\">https://t.co/gLtZSdDFmN</a>"
      end

      let(:api_response) do
        {
          created_at: "Mon May 13 22:45:04 +0000 2019",
          id: 1128068672289890305,
          id_str: "1128068672289890305",
          full_text: "Thank you to everyone who came out for #MetInParis last night for helping us support @EMMAUSolidarite &amp; @PompiersParis. #AWMH #MetalicaGivesBack https://t.co/gLtZSdDFmN",
          truncated: false,
          display_text_range: [0, 148],
          entities: {
            hashtags: [
              {
                text: "MetInParis",
                indices: [39, 50]
              },
              {
                text: "AWMH",
                indices: [124, 129]
              },
              {
                text: "MetalicaGivesBack",
                indices: [130, 148]
              }
            ],
            symbols: [],
            user_mentions: [
              {
                screen_name: "EMMAUSolidarite",
                name: "EMMAÜS Solidarité",
                id: 2912493406,
                id_str: "2912493406",
                indices: [85, 101]
              },
              {
                screen_name: "PompiersParis",
                name: "Pompiers de Paris",
                id: 1342191438,
                id_str: "1342191438",
                indices: [108, 122]
              }
            ],
            urls: [
              {
                url: "https://t.co/gLtZSdDFmN",
                expanded_url: "https://twitter.com/AWMHFoundation/status/1127646016931487744",
                display_url: "twitter.com/AWMHFoundation…",
                indices: [149, 172]
              }
            ]
          },
          source: "<a href=\"http://twitter.com\" rel=\"nofollow\">Twitter Web Client</a>",
          in_reply_to_status_id: nil,
          in_reply_to_status_id_str: nil,
          in_reply_to_user_id: nil,
          in_reply_to_user_id_str: nil,
          in_reply_to_screen_name: nil,
          user: {
            id: 238475531,
            id_str: "238475531",
            name: "Metallica",
            screen_name: "Metallica",
            location: "San Francisco, CA",
            description: "http://t.co/EAkqroM0OA | http://t.co/BEu6OVRhKG",
            url: "http://t.co/kVxaQpmqSI",
            entities: {
              url: {
                urls: [
                  {
                    url: "http://t.co/kVxaQpmqSI",
                    expanded_url: "http://www.metallica.com",
                    display_url: "metallica.com",
                    indices: [0, 22]
                  }
                ]
              },
              description: {
                urls: [
                  {
                    url: "http://t.co/EAkqroM0OA",
                    expanded_url: "http://metallica.com",
                    display_url: "metallica.com",
                    indices: [0, 22]
                  },
                  {
                    url: "http://t.co/BEu6OVRhKG",
                    expanded_url: "http://livemetallica.com",
                    display_url: "livemetallica.com",
                    indices: [25, 47]
                  }
                ]
              }
            },
            protected: false,
            followers_count: 5760661,
            friends_count: 31,
            listed_count: 12062,
            created_at: "Sat Jan 15 07:34:59 +0000 2011",
            favourites_count: 567,
            utc_offset: nil,
            time_zone: nil,
            geo_enabled: true,
            verified: true,
            statuses_count: 3764,
            lang: nil,
            contributors_enabled: false,
            is_translator: false,
            is_translation_enabled: false,
            profile_background_color: "000000",
            profile_background_image_url: "http://abs.twimg.com/images/themes/theme9/bg.gif",
            profile_background_image_url_https: "https://abs.twimg.com/images/themes/theme9/bg.gif",
            profile_background_tile: false,
            profile_image_url: "http://pbs.twimg.com/profile_images/766360293953802240/kt0hiSmv_normal.jpg",
            profile_image_url_https: "https://pbs.twimg.com/profile_images/766360293953802240/kt0hiSmv_normal.jpg",
            profile_banner_url: "https://pbs.twimg.com/profile_banners/238475531/1479538295",
            profile_link_color: "2FC2EF",
            profile_sidebar_border_color: "000000",
            profile_sidebar_fill_color: "252429",
            profile_text_color: "666666",
            profile_use_background_image: false,
            has_extended_profile: false,
            default_profile: false,
            default_profile_image: false,
            following: false,
            follow_request_sent: false,
            notifications: false,
            translator_type: "regular"
          },
          geo: nil,
          coordinates: nil,
          place: nil,
          contributors: nil,
          is_quote_status: true,
          quoted_status_id: 1127646016931487744,
          quoted_status_id_str: "1127646016931487744",
          quoted_status_permalink: {
            url: "https://t.co/gLtZSdDFmN",
            expanded: "https://twitter.com/AWMHFoundation/status/1127646016931487744",
            display: "twitter.com/AWMHFoundation…"
          },
          quoted_status: {
            created_at: "Sun May 12 18:45:35 +0000 2019",
            id: 1127646016931487744,
            id_str: "1127646016931487744",
            full_text: "If you bought a ticket for tonight’s @Metallica show at Stade de France, you have helped contribute to @EMMAUSolidarite &amp; @PompiersParis. #MetallicaGivesBack #AWMH #MetInParis https://t.co/wlUtDQbQEK",
            truncated: false,
            display_text_range: [0, 179],
            entities: {
              hashtags: [
                {
                  text: "MetallicaGivesBack",
                  indices: [142, 161]
                }, {
                  text: "AWMH",
                  indices: [162, 167]
                }, {
                  text: "MetInParis",
                  indices: [168, 179]
                }
              ],
              symbols: [],
              user_mentions: [
                {
                  screen_name: "Metallica",
                  name: "Metallica",
                  id: 238475531,
                  id_str: "238475531",
                  indices: [37, 47]
                }, {
                  screen_name: "EMMAUSolidarite",
                  name: "EMMAÜS Solidarité",
                  id: 2912493406,
                  id_str: "2912493406",
                  indices: [103, 119]
                }, {
                  screen_name: "PompiersParis",
                  name: "Pompiers de Paris",
                  id: 1342191438,
                  id_str: "1342191438",
                  indices: [126, 140]
                }
              ],
              urls: [],
              media: [
                {
                  id: 1127645176183250944,
                  id_str: "1127645176183250944",
                  indices: [180, 203],
                  media_url: "http://pbs.twimg.com/media/D6YzUC8V4AApDdF.jpg",
                  media_url_https: "https://pbs.twimg.com/media/D6YzUC8V4AApDdF.jpg",
                  url: "https://t.co/wlUtDQbQEK",
                  display_url: "pic.twitter.com/wlUtDQbQEK",
                  expanded_url: "https://twitter.com/AWMHFoundation/status/1127646016931487744/photo/1",
                  type: "photo",
                  sizes: {
                    large: {
                      w: 2048,
                      h: 1498,
                      resize: "fit"
                    },
                    thumb: {
                      w: 150,
                      h: 150,
                      resize: "crop"
                    },
                    medium: {
                      w: 1200,
                      h: 877,
                      resize: "fit"
                    },
                    small: {
                      w: 680,
                      h: 497,
                      resize: "fit"
                    }
                  }
                }
              ]
            },
            extended_entities: {
              media: [
                {
                  id: 1127645176183250944,
                  id_str: "1127645176183250944",
                  indices: [180, 203],
                  media_url: "http://pbs.twimg.com/media/D6YzUC8V4AApDdF.jpg",
                  media_url_https: "https://pbs.twimg.com/media/D6YzUC8V4AApDdF.jpg",
                  url: "https://t.co/wlUtDQbQEK",
                  display_url: "pic.twitter.com/wlUtDQbQEK",
                  expanded_url: "https://twitter.com/AWMHFoundation/status/1127646016931487744/photo/1",
                  type: "photo",
                  sizes: {
                    large: {
                      w: 2048,
                      h: 1498,
                      resize: "fit"
                    },
                    thumb: {
                      w: 150,
                      h: 150,
                      resize: "crop"
                    },
                    medium: {
                      w: 1200,
                      h: 877,
                      resize: "fit"
                    },
                    small: {
                      w: 680,
                      h: 497,
                      resize: "fit"
                    }
                  }
                }, {
                  id: 1127645195384774657,
                  id_str: "1127645195384774657",
                  indices: [180, 203],
                  media_url: "http://pbs.twimg.com/media/D6YzVKeV4AEPpSQ.jpg",
                  media_url_https: "https://pbs.twimg.com/media/D6YzVKeV4AEPpSQ.jpg",
                  url: "https://t.co/wlUtDQbQEK",
                  display_url: "pic.twitter.com/wlUtDQbQEK",
                  expanded_url: "https://twitter.com/AWMHFoundation/status/1127646016931487744/photo/1",
                  type: "photo",
                  sizes: {
                    thumb: {
                      w: 150,
                      h: 150,
                      resize: "crop"
                    },
                    medium: {
                      w: 1200,
                      h: 922,
                      resize: "fit"
                    },
                    small: {
                      w: 680,
                      h: 522,
                      resize: "fit"
                    },
                    large: {
                      w: 2048,
                      h: 1574,
                      resize: "fit"
                    }
                  }
                }
              ]
            },
            source: "<a href=\"http://twitter.com\" rel=\"nofollow\">Twitter Web Client</a>",
            in_reply_to_status_id: nil,
            in_reply_to_status_id_str: nil,
            in_reply_to_user_id: nil,
            in_reply_to_user_id_str: nil,
            in_reply_to_screen_name: nil,
            user: {
              id: 886959980254871552,
              id_str: "886959980254871552",
              name: "All Within My Hands Foundation",
              screen_name: "AWMHFoundation",
              location: "",
              description: "",
              url: "https://t.co/KgwIPrVVhg",
              entities: {
                url: {
                  urls: [
                    {
                      url: "https://t.co/KgwIPrVVhg",
                      expanded_url: "http://allwithinmyhands.org",
                      display_url: "allwithinmyhands.org",
                      indices: [0, 23]
                    }
                  ]
                },
                description: {
                  urls: []
                }
              },
              protected: false,
              followers_count: 5962,
              friends_count: 6,
              listed_count: 15,
              created_at: "Mon Jul 17 14:45:13 +0000 2017",
              favourites_count: 30,
              utc_offset: nil,
              time_zone: nil,
              geo_enabled: true,
              verified: false,
              statuses_count: 241,
              lang: nil,
              contributors_enabled: false,
              is_translator: false,
              is_translation_enabled: false,
              profile_background_color: "000000",
              profile_background_image_url: "http://abs.twimg.com/images/themes/theme1/bg.png",
              profile_background_image_url_https: "https://abs.twimg.com/images/themes/theme1/bg.png",
              profile_background_tile: false,
              profile_image_url: "http://pbs.twimg.com/profile_images/935181032185241600/D8FoOIRJ_normal.jpg",
              profile_image_url_https: "https://pbs.twimg.com/profile_images/935181032185241600/D8FoOIRJ_normal.jpg",
              profile_banner_url: "https://pbs.twimg.com/profile_banners/886959980254871552/1511799663",
              profile_link_color: "000000",
              profile_sidebar_border_color: "000000",
              profile_sidebar_fill_color: "000000",
              profile_text_color: "000000",
              profile_use_background_image: false,
              has_extended_profile: false,
              default_profile: false,
              default_profile_image: false,
              following: false,
              follow_request_sent: false,
              notifications: false,
              translator_type: "none"
            },
            geo: nil,
            coordinates: nil,
            place: nil,
            contributors: nil,
            is_quote_status: false,
            retweet_count: 46,
            favorite_count: 275,
            favorited: false,
            retweeted: false,
            possibly_sensitive: false,
            possibly_sensitive_appealable: false,
            lang: "en"
          },
          retweet_count: 201,
          favorite_count: 1664,
          favorited: false,
          retweeted: false,
          possibly_sensitive: false,
          possibly_sensitive_appealable: false,
          lang: "en"
        }
      end

      include_context "quoted tweet info"
      include_context "engines"

      it_behaves_like "an engine"
      it_behaves_like '#to_html'
      it_behaves_like "includes quoted tweet data"
    end
  end
end
