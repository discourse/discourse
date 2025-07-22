# frozen_string_literal: true

require "rails_helper"

describe GithubLinkbackAccessTokenSettingValidator do
  subject(:validator) { described_class.new }

  let(:value) { SecureRandom.hex(10) }

  before { enable_current_plugin }

  describe "#valid_value?" do
    context "when an Octokit::Unauthorized error is raised, meaning the access token cannot access a repo" do
      before do
        setup_repos
        Octokit::Client.any_instance.expects(:branches).raises(Octokit::Unauthorized)
      end

      it "should fail" do
        expect(validator.valid_value?(value)).to eq(false)
      end
    end

    context "when no Octokit::Unauthorized error is raised" do
      it "should pass, without repos defined" do
        expect(validator.valid_value?(value)).to eq(true)
      end

      context "when there are repos defined" do
        before do
          setup_repos
          Octokit::Client.any_instance.expects(:branches).returns([])
        end

        it "should pass if all the repos are accessible" do
          expect(validator.valid_value?(value)).to eq(true)
        end
      end
    end
  end

  def setup_repos
    SiteSetting.github_badges_repos = "discourse/discourse"
    DiscourseGithubPlugin::GithubRepo.repos
  end
end
