# frozen_string_literal: true

describe ProblemCheck::GithubBadgesRepo do
  subject(:check) { described_class.new("discourse/discourse") }

  before do
    enable_current_plugin
    SiteSetting.github_badges_enabled = true
    SiteSetting.github_linkback_access_token = "token"
    SiteSetting.github_badges_repos = "discourse/discourse"
  end

  def stub_repo(status: 200, full_name: "discourse/discourse")
    stub_request(:get, "https://api.github.com/repos/discourse/discourse").to_return(
      status:,
      body: { full_name: }.to_json,
    )
  end

  it "is only enabled when badges can be populated" do
    expect(described_class).to be_enabled

    SiteSetting.github_linkback_access_token = ""
    expect(described_class).not_to be_enabled

    SiteSetting.github_linkback_access_token = "token"
    SiteSetting.github_badges_repos = ""
    expect(described_class).not_to be_enabled
  end

  it "reports a repo that has moved" do
    stub_repo(full_name: "discourse/renamed")

    expect(check).to have_a_problem.with_message(
      I18n.t(
        "dashboard.problem.github_badges_repo_moved",
        repo: "discourse/discourse",
        new_name: "discourse/renamed",
      ),
    )
  end

  it "reports a repo that is not found" do
    stub_repo(status: 404)

    expect(check).to have_a_problem.with_message(
      I18n.t("dashboard.problem.github_badges_repo_not_found", repo: "discourse/discourse"),
    )
  end

  it "is chill about a repo whose name only differs in case" do
    stub_repo(full_name: "Discourse/Discourse")

    expect(check).to be_chill_about_it
  end

  it "is chill about a rejected token, which has its own check" do
    stub_repo(status: 401)

    expect(check).to be_chill_about_it
  end

  it "lets other errors through so an existing notice is kept" do
    stub_repo(status: 500)

    expect { check.call }.to raise_error(Discourse::GithubApi::Error)
  end
end
