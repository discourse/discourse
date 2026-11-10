# frozen_string_literal: true

describe DiscourseGithubPlugin::GithubRepo do
  before { enable_current_plugin }

  describe ".names" do
    it "extracts the repo names from the badges repos setting" do
      SiteSetting.github_badges_repos =
        "https://github.com/discourse/discourse.git|https://github.com/discourse/onebox/|discourse/somerepo_with-numbers7"

      expect(described_class.names).to eq(
        %w[discourse/discourse discourse/onebox discourse/somerepo_with-numbers7],
      )
      expect(described_class.count).to eq(0)
    end
  end

  describe ".repos" do
    it "finds or creates a repo for each name" do
      SiteSetting.github_badges_repos = "discourse/discourse"

      expect(described_class.repos.map(&:name)).to eq(%w[discourse/discourse])
      expect { described_class.repos }.not_to change { described_class.count }
    end
  end
end
