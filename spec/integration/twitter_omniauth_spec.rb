# frozen_string_literal: true

describe "Twitter OAuth 1.0a" do
  let(:access_token) { "twitter_access_token_448" }
  let(:consumer_key) { "abcdef11223344" }
  let(:consumer_secret) { "adddcccdddd99922" }
  let(:oauth_token_secret) { "twitter_temp_code_544254" }

  fab!(:user1) { Fabricate(:user) }

  def setup_twitter_email_stub(email:)
    body = {
      contributors_enabled: true,
      created_at: "Sat May 09 17:58:22 +0000 2009",
      default_profile: false,
      default_profile_image: false,
      description:
        "I taught your phone that thing you like.  The Mobile Partner Engineer @Twitter. ",
      favourites_count: 588,
      follow_request_sent: nil,
      followers_count: 10_625,
      following: nil,
      friends_count: 1181,
      geo_enabled: true,
      id: 38_895_958,
      id_str: "38895958",
      is_translator: false,
      lang: "en",
      listed_count: 190,
      location: "San Francisco",
      name: "Sean Cook",
      notifications: nil,
      profile_background_color: "1A1B1F",
      profile_background_image_url:
        "http://a0.twimg.com/profile_background_images/495742332/purty_wood.png",
      profile_background_image_url_https:
        "https://si0.twimg.com/profile_background_images/495742332/purty_wood.png",
      profile_background_tile: true,
      profile_image_url: "http://a0.twimg.com/profile_images/1751506047/dead_sexy_normal.JPG",
      profile_image_url_https:
        "https://si0.twimg.com/profile_images/1751506047/dead_sexy_normal.JPG",
      profile_link_color: "2FC2EF",
      profile_sidebar_border_color: "181A1E",
      profile_sidebar_fill_color: "252429",
      profile_text_color: "666666",
      profile_use_background_image: true,
      protected: false,
      screen_name: "theSeanCook",
      show_all_inline_media: true,
      statuses_count: 2609,
      time_zone: "Pacific Time (US & Canada)",
      url: nil,
      utc_offset: -28_800,
      verified: true,
      email: email,
    }
    stub_request(:get, "https://api.twitter.com/1.1/account/verify_credentials.json").with(
      query: {
        include_email: true,
        include_entities: false,
        skip_status: true,
      },
    ).to_return(status: 200, body: JSON.dump(body))
  end

  before do
    SiteSetting.enable_twitter_logins = true
    SiteSetting.twitter_consumer_key = consumer_key
    SiteSetting.twitter_consumer_secret = consumer_secret

    stub_request(:post, "https://api.twitter.com/oauth/request_token").to_return(
      status: 200,
      body:
        Rack::Utils.build_query(
          oauth_token: access_token,
          oauth_token_secret: oauth_token_secret,
          oauth_callback_confirmed: true,
        ),
      headers: {
        "Content-Type" => "application/x-www-form-urlencoded",
      },
    )
    stub_request(:post, "https://api.twitter.com/oauth/access_token").to_return(
      status: 200,
      body:
        Rack::Utils.build_query(
          oauth_token: access_token,
          oauth_token_secret: oauth_token_secret,
          user_id: "43423432422",
          screen_name: "twitterapi",
        ),
    )
  end

  it "signs in the user if the API response from twitter includes an email (implies it's verified) and the email matches an existing user's" do
    post "/auth/twitter"
    expect(response.status).to eq(302)
    expect(response.location).to start_with("https://api.twitter.com/oauth/authenticate")

    setup_twitter_email_stub(email: user1.email)

    post "/auth/twitter/callback", params: { state: session["omniauth.state"] }

    expect(response.status).to eq(302)
    expect(response.location).to eq("http://test.localhost/")
    expect(session[:current_user_id]).to eq(user1.id)
  end

  it "doesn't sign in the user discourse connect is enabled" do
    SiteSetting.discourse_connect_url = "https://example.com/sso"
    SiteSetting.enable_discourse_connect = true
    post "/auth/twitter"
    expect(response.status).to eq(302)
    expect(response.location).to start_with("https://api.twitter.com/oauth/authenticate")

    setup_twitter_email_stub(email: user1.email)

    post "/auth/twitter/callback", params: { state: session["omniauth.state"] }

    expect(response.status).to eq(403)
    expect(session[:current_user_id]).to be_blank
  end

  it "doesn't sign in anyone if the API response from twitter doesn't include an email (implying the user's email on twitter isn't verified)" do
    post "/auth/twitter"
    expect(response.status).to eq(302)
    expect(response.location).to start_with("https://api.twitter.com/oauth/authenticate")

    setup_twitter_email_stub(email: nil)

    post "/auth/twitter/callback", params: { state: session["omniauth.state"] }

    expect(response.status).to eq(302)
    expect(response.location).to eq("http://test.localhost/")
    expect(session[:current_user_id]).to be_blank
  end
end
