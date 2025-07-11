# frozen_string_literal: true

require "rails_helper"

describe DiscourseGithubPlugin::GithubRepo do
  it "strips .git from url" do
    SiteSetting.github_badges_repos = "https://github.com/discourse/discourse.git"
    repo = DiscourseGithubPlugin::GithubRepo.repos.first
    expect(repo.name).to eq("discourse/discourse")
  end

  it "strips trailing slash from url" do
    SiteSetting.github_badges_repos = "https://github.com/discourse/discourse/"
    repo = DiscourseGithubPlugin::GithubRepo.repos.first
    expect(repo.name).to eq("discourse/discourse")
  end

  it "doesn't raise an error when the site setting follows the user/repo format" do
    SiteSetting.github_badges_repos = "discourse/discourse-github"
    repo = DiscourseGithubPlugin::GithubRepo.repos.first
    expect(repo.name).to eq("discourse/discourse-github")

    SiteSetting.github_badges_repos = "discourse/somerepo_with-numbers7"
    repo = DiscourseGithubPlugin::GithubRepo.repos.first
    expect(repo.name).to eq("discourse/somerepo_with-numbers7")
  end
end
