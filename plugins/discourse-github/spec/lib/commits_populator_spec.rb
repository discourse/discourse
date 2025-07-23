# frozen_string_literal: true

require "rails_helper"

describe DiscourseGithubPlugin::CommitsPopulator do
  subject(:populator) { described_class.new(repo) }

  let(:repo) { DiscourseGithubPlugin::GithubRepo.new(name: "discourse/discourse") }
  let!(:site_admin1) { Fabricate(:admin) }
  let!(:site_admin2) { Fabricate(:admin) }

  before do
    enable_current_plugin
    SiteSetting.github_badges_enabled = true
  end

  context "when invalid credentials have been provided for octokit" do
    before { Octokit::Client.any_instance.expects(:branches).raises(Octokit::Unauthorized) }

    it "disables github badges and sends a PM to the admin of the site to inform them" do
      populator.populate!
      expect(SiteSetting.github_badges_enabled).to eq(false)
      sent_pm =
        Post
          .joins(:topic)
          .includes(:topic)
          .where("topics.archetype = ?", Archetype.private_message)
          .last
      expect(sent_pm.topic.allowed_users.include?(site_admin1)).to eq(true)
      expect(sent_pm.topic.allowed_users.include?(site_admin2)).to eq(true)
      expect(sent_pm.topic.title).to eq(
        I18n.t("github_commits_populator.errors.invalid_octokit_credentials_pm_title"),
      )
      expect(sent_pm.raw).to eq(
        I18n.t(
          "github_commits_populator.errors.invalid_octokit_credentials_pm",
          base_path: Discourse.base_path,
        ).strip,
      )
    end
  end

  context "when the repository is not found" do
    before { Octokit::Client.any_instance.expects(:branches).raises(Octokit::NotFound) }

    it "disables github badges and sends a PM to the admin of the site to inform them" do
      populator.populate!
      expect(SiteSetting.github_badges_enabled).to eq(false)
      sent_pm =
        Post
          .joins(:topic)
          .includes(:topic)
          .where("topics.archetype = ?", Archetype.private_message)
          .last
      expect(sent_pm.topic.allowed_users.include?(site_admin1)).to eq(true)
      expect(sent_pm.topic.allowed_users.include?(site_admin2)).to eq(true)
      expect(sent_pm.topic.title).to eq(
        I18n.t("github_commits_populator.errors.repository_not_found_pm_title"),
      )
      expect(sent_pm.raw).to eq(
        I18n.t(
          "github_commits_populator.errors.repository_not_found_pm",
          repo_name: repo.name,
          base_path: Discourse.base_path,
        ).strip,
      )
    end
  end

  context "when the repository identifier is invalid" do
    before { Octokit::Client.any_instance.expects(:branches).raises(Octokit::InvalidRepository) }

    it "disables github badges and sends a PM to the admin of the site to inform them" do
      populator.populate!
      expect(SiteSetting.github_badges_enabled).to eq(false)
      sent_pm =
        Post
          .joins(:topic)
          .includes(:topic)
          .where("topics.archetype = ?", Archetype.private_message)
          .last
      expect(sent_pm.topic.allowed_users.include?(site_admin1)).to eq(true)
      expect(sent_pm.topic.allowed_users.include?(site_admin2)).to eq(true)
      expect(sent_pm.topic.title).to eq(
        I18n.t("github_commits_populator.errors.repository_identifier_invalid_pm_title"),
      )
      expect(sent_pm.raw).to eq(
        I18n.t(
          "github_commits_populator.errors.repository_identifier_invalid_pm",
          repo_name: repo.name,
          base_path: Discourse.base_path,
        ).strip,
      )
    end
  end

  context "if some other octokit error is raised" do
    before { Octokit::Client.any_instance.expects(:branches).raises(Octokit::Error) }

    it "simply logs the error and does nothing else" do
      populator.populate!
      expect(SiteSetting.github_badges_enabled).to eq(true)
    end
  end

  context "if GraphQL returns no data" do
    before do
      branches_body = <<~JSON
        [
          {
            "name": "add-group-css-properties",
            "commit": {
              "sha": "0d67b6307042803c351599de715023841cfa9356",
              "url": "https://api.github.com/repos/discourse/discourse/commits/0d67b6307042803c351599de715023841cfa9356"
            },
            "protected": false
          }
        ]
      JSON

      graphql_response = <<~JSON
        {
          "message": "Bad credentials",
          "documentation_url": "https://docs.github.com/graphql"
        }
      JSON

      stub_request(
        :get,
        "https://api.github.com/repos/discourse/discourse/branches?per_page=100",
      ).to_return(status: 200, body: branches_body)
      stub_request(:post, "https://api.github.com/graphql").to_return(
        status: 200,
        body: graphql_response,
        headers: {
          "content-type": "application/json",
        },
      )
    end

    it "simply logs the error and does nothing else" do
      expect { populator.populate! }.to raise_error(described_class::GraphQLError)
    end
  end

  context "if github_badges_enabled is false" do
    before { SiteSetting.github_badges_enabled = false }

    it "early returns before attempting to execute any of the commit fetching, because the plugin likely disabled itself" do
      Octokit::Client.any_instance.expects(:branches).never
      populator.populate!
    end
  end
end
