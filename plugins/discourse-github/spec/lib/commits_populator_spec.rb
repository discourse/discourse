# frozen_string_literal: true

describe DiscourseGithubPlugin::CommitsPopulator do
  subject(:populator) { described_class.new(repo) }

  let(:repo) { DiscourseGithubPlugin::GithubRepo.new(name: "discourse/discourse") }
  let!(:site_admin1) { Fabricate(:admin) }
  let!(:site_admin2) { Fabricate(:admin) }
  let(:branches_url) { "https://api.github.com/repos/discourse/discourse/branches" }

  before do
    enable_current_plugin
    SiteSetting.github_badges_enabled = true
  end

  def last_pm
    Post
      .joins(:topic)
      .includes(:topic)
      .where("topics.archetype = ?", Archetype.private_message)
      .last
  end

  context "when invalid credentials have been provided (401)" do
    before { stub_request(:get, branches_url).to_return(status: 401) }

    it "disables github badges and sends a PM to the admin of the site to inform them" do
      populator.populate!
      expect(SiteSetting.github_badges_enabled).to eq(false)
      expect(last_pm.topic.allowed_users).to include(site_admin1, site_admin2)
      expect(last_pm.topic.title).to eq(
        I18n.t("github_commits_populator.errors.invalid_octokit_credentials_pm_title"),
      )
      expect(last_pm.raw).to eq(
        I18n.t(
          "github_commits_populator.errors.invalid_octokit_credentials_pm",
          base_path: Discourse.base_path,
        ).strip,
      )
    end
  end

  context "when the repository is not found (404)" do
    before { stub_request(:get, branches_url).to_return(status: 404) }

    it "disables github badges and sends a PM to the admin of the site to inform them" do
      populator.populate!
      expect(SiteSetting.github_badges_enabled).to eq(false)
      expect(last_pm.topic.allowed_users).to include(site_admin1, site_admin2)
      expect(last_pm.topic.title).to eq(
        I18n.t("github_commits_populator.errors.repository_not_found_pm_title"),
      )
      expect(last_pm.raw).to eq(
        I18n.t(
          "github_commits_populator.errors.repository_not_found_pm",
          repo_name: repo.name,
          base_path: Discourse.base_path,
        ).strip,
      )
    end
  end

  context "if some other GitHub error is raised (500)" do
    before { stub_request(:get, branches_url).to_return(status: 500) }

    it "simply logs the error and does nothing else" do
      populator.populate!
      expect(SiteSetting.github_badges_enabled).to eq(true)
    end
  end

  context "if GraphQL returns no data" do
    before do
      stub_request(:get, branches_url).to_return(
        status: 200,
        body: [{ "name" => "main", "commit" => { "sha" => "abc" } }].to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      )
      stub_request(:post, "https://api.github.com/graphql").to_return(
        status: 200,
        body: { "message" => "Bad credentials" }.to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      )
    end

    it "raises a GraphQLError" do
      expect { populator.populate! }.to raise_error(described_class::GraphQLError)
    end
  end

  context "if github_badges_enabled is false" do
    before { SiteSetting.github_badges_enabled = false }

    it "early returns before making any GitHub request" do
      populator.populate!
      expect(a_request(:get, branches_url)).not_to have_been_made
    end
  end
end
