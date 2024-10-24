# frozen_string_literal: true

describe "GitHub Oauth2" do
  let(:access_token) { "github_access_token_448" }
  let(:client_id) { "abcdef11223344" }
  let(:client_secret) { "adddcccdddd99922" }
  let(:temp_code) { "github_temp_code_544254" }

  fab!(:user1) { Fabricate(:user) }
  fab!(:user2) { Fabricate(:user) }

  def setup_github_emails_stub(emails)
    stub_request(:get, "https://api.github.com/user/emails").with(
      headers: {
        "Authorization" => "Bearer #{access_token}",
      },
    ).to_return(
      status: 200,
      body: JSON.dump(emails),
      headers: {
        "Content-Type" => "application/json",
      },
    )
  end

  before do
    SiteSetting.enable_github_logins = true
    SiteSetting.github_client_id = client_id
    SiteSetting.github_client_secret = client_secret

    stub_request(:post, "https://github.com/login/oauth/access_token").with(
      body:
        hash_including(
          "client_id" => client_id,
          "client_secret" => client_secret,
          "code" => temp_code,
        ),
    ).to_return(
      status: 200,
      body:
        Rack::Utils.build_query(
          access_token: access_token,
          scope: "user:email",
          token_type: "bearer",
        ),
      headers: {
        "Content-Type" => "application/x-www-form-urlencoded",
      },
    )

    stub_request(:get, "https://api.github.com/user").with(
      headers: {
        "Authorization" => "Bearer #{access_token}",
      },
    ).to_return(
      status: 200,
      body:
        JSON.dump(
          login: "octocat",
          id: 1,
          node_id: "MDQ6VXNlcjE=",
          avatar_url: "https://github.com/images/error/octocat_happy.gif",
          gravatar_id: "",
          url: "https://api.github.com/users/octocat",
          html_url: "https://github.com/octocat",
          followers_url: "https://api.github.com/users/octocat/followers",
          following_url: "https://api.github.com/users/octocat/following{/other_user}",
          gists_url: "https://api.github.com/users/octocat/gists{/gist_id}",
          starred_url: "https://api.github.com/users/octocat/starred{/owner}{/repo}",
          subscriptions_url: "https://api.github.com/users/octocat/subscriptions",
          organizations_url: "https://api.github.com/users/octocat/orgs",
          repos_url: "https://api.github.com/users/octocat/repos",
          events_url: "https://api.github.com/users/octocat/events{/privacy}",
          received_events_url: "https://api.github.com/users/octocat/received_events",
          type: "User",
          site_admin: false,
          name: "monalisa octocat",
          company: "GitHub",
          blog: "https://github.com/blog",
          location: "San Francisco",
          email: "octocat@github.com",
          hireable: false,
          bio: "There once was...",
          twitter_username: "monatheoctocat",
          public_repos: 2,
          public_gists: 1,
          followers: 20,
          following: 0,
          created_at: "2008-01-14T04:33:35Z",
          updated_at: "2008-01-14T04:33:35Z",
          private_gists: 81,
          total_private_repos: 100,
          owned_private_repos: 100,
          disk_usage: 10_000,
          collaborators: 8,
          two_factor_authentication: true,
          plan: {
            name: "Medium",
            space: 400,
            private_repos: 20,
            collaborators: 0,
          },
        ),
      headers: {
        "Content-Type" => "application/json",
      },
    )
  end

  it "doesn't sign in anyone if none of the emails from github are verified" do
    post "/auth/github"
    expect(response.status).to eq(302)
    expect(response.location).to start_with("https://github.com/login/oauth/authorize?")

    setup_github_emails_stub(
      [
        { email: user1.email, primary: true, verified: false, visibility: "private" },
        { email: user2.email, primary: false, verified: false, visibility: "private" },
      ],
    )

    post "/auth/github/callback", params: { state: session["omniauth.state"], code: temp_code }
    expect(response.status).to eq(302)
    expect(response.location).to eq("http://test.localhost/")
    expect(session[:current_user_id]).to be_blank
  end

  it "matches a non-primary email if it's verified and the primary email isn't" do
    post "/auth/github"
    expect(response.status).to eq(302)
    expect(response.location).to start_with("https://github.com/login/oauth/authorize?")

    setup_github_emails_stub(
      [
        { email: user1.email, primary: true, verified: false, visibility: "private" },
        { email: user2.email, primary: false, verified: true, visibility: "private" },
      ],
    )

    post "/auth/github/callback", params: { state: session["omniauth.state"], code: temp_code }
    expect(response.status).to eq(302)
    expect(response.location).to eq("http://test.localhost/")
    expect(session[:current_user_id]).to eq(user2.id)
  end

  it "doesn't match a non-primary email if it's not verified" do
    post "/auth/github"
    expect(response.status).to eq(302)
    expect(response.location).to start_with("https://github.com/login/oauth/authorize?")

    setup_github_emails_stub(
      [
        {
          email: "somerandomemail@discourse.org",
          primary: true,
          verified: true,
          visibility: "private",
        },
        { email: user2.email, primary: false, verified: false, visibility: "private" },
      ],
    )

    post "/auth/github/callback", params: { state: session["omniauth.state"], code: temp_code }
    expect(response.status).to eq(302)
    expect(response.location).to eq("http://test.localhost/")
    expect(session[:current_user_id]).to be_blank
  end

  it "favors the primary email over secondary emails when they're all verified" do
    post "/auth/github"
    expect(response.status).to eq(302)
    expect(response.location).to start_with("https://github.com/login/oauth/authorize?")

    setup_github_emails_stub(
      [
        { email: user1.email, primary: true, verified: true, visibility: "private" },
        { email: user2.email, primary: false, verified: true, visibility: "private" },
      ],
    )

    post "/auth/github/callback", params: { state: session["omniauth.state"], code: temp_code }
    expect(response.status).to eq(302)
    expect(response.location).to eq("http://test.localhost/")
    expect(session[:current_user_id]).to eq(user1.id)
  end

  it "doesn't log in the user if discourse connect is enabled" do
    SiteSetting.discourse_connect_url = "https://example.com/sso"
    SiteSetting.enable_discourse_connect = true
    post "/auth/github"
    expect(response.status).to eq(302)
    expect(response.location).to start_with("https://github.com/login/oauth/authorize?")

    setup_github_emails_stub(
      [
        { email: user1.email, primary: true, verified: true, visibility: "private" },
        { email: user2.email, primary: false, verified: true, visibility: "private" },
      ],
    )

    post "/auth/github/callback", params: { state: session["omniauth.state"], code: temp_code }
    expect(response.status).to eq(403)
    expect(session[:current_user_id]).to be_blank
  end
end
