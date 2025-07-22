# frozen_string_literal: true

require "rails_helper"

describe DiscourseGithubPlugin::GithubBadges do
  let(:bronze_user) { Fabricate(:user) }
  let(:bronze_user_repo_2) { Fabricate(:user) }
  let(:silver_user) { Fabricate(:user) }
  let(:contributor) { Fabricate(:user) }
  let(:private_email_contributor) { Fabricate(:user) }
  let(:private_email_contributor2) { Fabricate(:user) }
  let(:merge_commit_user) { Fabricate(:user) }
  let(:staged_user) { Fabricate(:user, staged: true) }

  before { enable_current_plugin }

  describe "committer and contributor badges" do
    before do
      roles = DiscourseGithubPlugin::CommitsPopulator::ROLES
      SiteSetting.github_badges_repos =
        "https://github.com/org/repo1.git|https://github.com/org/repo2.git"
      repo1 = DiscourseGithubPlugin::GithubRepo.repos.find { |repo| repo.name == "org/repo1" }
      repo2 = DiscourseGithubPlugin::GithubRepo.repos.find { |repo| repo.name == "org/repo2" }
      repo1.commits.create!(
        sha: "1",
        email: bronze_user.email,
        committed_at: 1.day.ago,
        role_id: roles[:committer],
      )
      repo1.commits.create!(
        sha: "2",
        email: merge_commit_user.email,
        merge_commit: true,
        committed_at: 1.day.ago,
        role_id: roles[:committer],
      )
      repo1.commits.create!(
        sha: "3",
        email: contributor.email,
        committed_at: 1.day.ago,
        role_id: roles[:contributor],
      )
      25.times do |n|
        repo1.commits.create!(
          sha: "blah#{n}",
          email: silver_user.email,
          committed_at: 1.day.ago,
          role_id: roles[:committer],
        )
      end
      repo2.commits.create!(
        sha: "4",
        email: bronze_user_repo_2.email,
        committed_at: 2.day.ago,
        role_id: roles[:committer],
      )

      UserAssociatedAccount.create!(
        provider_name: "github",
        user_id: private_email_contributor.id,
        info: {
          nickname: "bob",
        },
        provider_uid: 100,
      )
      repo1.commits.create!(
        sha: "123",
        email: "100+bob@users.noreply.github.com",
        committed_at: 1.day.ago,
        role_id: roles[:contributor],
      )

      UserAssociatedAccount.create!(
        provider_name: "github",
        user_id: private_email_contributor2.id,
        info: {
          nickname: "joe",
        },
        provider_uid: 101,
      )
      repo1.commits.create!(
        sha: "124",
        email: "joe@users.noreply.github.com",
        committed_at: 1.day.ago,
        role_id: roles[:contributor],
      )

      repo1.commits.create!(
        sha: "5",
        email: staged_user.email,
        committed_at: 1.day.ago,
        role_id: roles[:contributor],
      )
    end

    it "granted correctly" do
      # initial run to seed badges and then enable them
      DiscourseGithubPlugin::GithubBadges.grant!

      contributor_bronze = DiscourseGithubPlugin::GithubBadges::BADGE_NAME_BRONZE
      committer_bronze = DiscourseGithubPlugin::GithubBadges::COMMITTER_BADGE_NAME_BRONZE
      committer_silver = DiscourseGithubPlugin::GithubBadges::COMMITTER_BADGE_NAME_SILVER

      users = [
        bronze_user,
        bronze_user_repo_2,
        silver_user,
        contributor,
        staged_user,
        private_email_contributor,
        private_email_contributor2,
        merge_commit_user,
      ]
      users.each { |u| u.badges.destroy_all }

      [committer_bronze, committer_silver].each do |name|
        Badge.find_by(name: name).update!(enabled: true)
      end

      DiscourseGithubPlugin::GithubBadges.grant!
      users.each(&:reload)

      expect(merge_commit_user.badges).to eq([])
      [bronze_user, bronze_user_repo_2].each_with_index do |u, ind|
        expect(u.badges.pluck(:name)).to eq([committer_bronze])
      end
      expect(contributor.badges.pluck(:name)).to eq([contributor_bronze])
      expect(private_email_contributor.badges.pluck(:name)).to eq([contributor_bronze])
      expect(private_email_contributor2.badges.pluck(:name)).to eq([contributor_bronze])
      expect(silver_user.badges.pluck(:name)).to contain_exactly(committer_bronze, committer_silver)

      # does not grant badges to staged users
      expect(staged_user.badges.first).to eq(nil)
    end

    it "does not update user title if badge is not allowed to be used as a title" do
      DiscourseGithubPlugin::GithubBadges.grant!
      silver_committer_badge =
        Badge.find_by(name: DiscourseGithubPlugin::GithubBadges::COMMITTER_BADGE_NAME_SILVER)

      silver_committer_badge.update!(enabled: true)
      DiscourseGithubPlugin::GithubBadges.grant!
      expect(silver_user.reload.title).to eq(nil)

      silver_committer_badge.update!(allow_title: true)
      DiscourseGithubPlugin::GithubBadges.grant!
      expect(silver_user.reload.title).to eq(silver_committer_badge.name)
    end

    it "updates existing badges" do
      badge = Badge.create!(name: "Great contributor", badge_type_id: 2)
      DiscourseGithubPlugin::GithubBadges.contributor_badges

      expect(badge.reload.name).to eq("Great Contributor")
    end
  end
end
