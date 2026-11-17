# frozen_string_literal: true

describe ProblemCheck::GithubLinkbackAccessTokenInvalid do
  subject(:check) { described_class.new }

  before do
    enable_current_plugin
    SiteSetting.github_linkback_access_token = "token"
  end

  def stub_rate_limit(status:)
    stub_request(:get, "https://api.github.com/rate_limit").to_return(status:, body: "{}")
  end

  it "is only enabled when a token is configured" do
    expect(described_class).to be_enabled

    SiteSetting.github_linkback_access_token = ""
    expect(described_class).not_to be_enabled
  end

  it "reports a token GitHub rejects" do
    stub_rate_limit(status: 401)
    expect(check).to have_a_problem.with_priority("high")
  end

  it "is chill about a token GitHub accepts" do
    stub_rate_limit(status: 200)
    expect(check).to be_chill_about_it
  end

  it "lets other errors through so an existing notice is kept" do
    stub_rate_limit(status: 500)
    expect { check.call }.to raise_error(Discourse::GithubApi::Error)
  end
end
