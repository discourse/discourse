# frozen_string_literal: true

module DiscourseGithubPlugin
  module GithubBadges
    BADGE_NAME_BRONZE = "Contributor"
    BADGE_NAME_SILVER = "Great Contributor"
    BADGE_NAME_GOLD = "Amazing Contributor"

    COMMITTER_BADGE_NAME_BRONZE = "Committer"
    COMMITTER_BADGE_NAME_SILVER = "Frequent Committer"
    COMMITTER_BADGE_NAME_GOLD = "Amazing Committer"

    class Granter
      def initialize(emails)
        @emails = emails
        @badges = []
      end

      def add_badge(badge, as_title:, threshold:)
        @badges << [badge, as_title, threshold]
      end

      def grant!
        email_commits = @emails.group_by { |e| e }.map { |k, l| [k, l.count] }.to_h

        regular_emails = []
        github_name_email = {}
        @emails.each do |email|
          match = email.match(/\A(\d+\+)?(?<name>.+)@users.noreply.github.com\Z/)

          if match
            name = match[:name]
            github_name_email[name] = email
          else
            regular_emails << email
          end
        end

        user_emails = {}
        User
          .real
          .where(staged: false)
          .with_email(regular_emails)
          .each { |user| user_emails[user] = user.emails }

        if github_name_email.any?
          screen_names =
            UserAssociatedAccount
              .where(provider_name: "github")
              .where("info ->> 'nickname' IN (?)", github_name_email.keys)
              .includes(:user)
              .map { |row| [row.user, row.info["nickname"]] }
              .to_h

          screen_names.each do |user, screen_name|
            user_emails[user] ||= []
            user_emails[user] << github_name_email[screen_name]
          end
        end

        user_emails.each do |user, emails|
          commits_count = emails.sum { |email| email_commits[email] || 0 }
          @badges.each do |badge, as_title, threshold|
            if commits_count >= threshold && badge.enabled? && SiteSetting.enable_badges
              BadgeGranter.grant(badge, user)
              user.update!(title: badge.name) if badge.allow_title? && user.title.blank? && as_title
            end
          end
        end
      end
    end

    def self.grant!
      grant_committer_badges!
      grant_contributor_badges!
    end

    def self.grant_committer_badges!
      emails =
        GithubCommit.where(merge_commit: false, role_id: CommitsPopulator::ROLES[:committer]).pluck(
          :email,
        )

      bronze, silver, gold = committer_badges

      granter = GithubBadges::Granter.new(emails)
      granter.add_badge(bronze, as_title: false, threshold: 1)
      granter.add_badge(silver, as_title: true, threshold: 25)
      granter.add_badge(gold, as_title: true, threshold: 1000)
      granter.grant!
    end

    def self.grant_contributor_badges!
      emails =
        GithubCommit.where(
          merge_commit: false,
          role_id: CommitsPopulator::ROLES[:contributor],
        ).pluck(:email)

      bronze, silver, gold = contributor_badges

      granter = GithubBadges::Granter.new(emails)
      granter.add_badge(bronze, as_title: false, threshold: 1)
      granter.add_badge(
        silver,
        as_title: true,
        threshold: SiteSetting.github_silver_badge_min_commits,
      )
      granter.add_badge(gold, as_title: true, threshold: SiteSetting.github_gold_badge_min_commits)
      granter.grant!
    end

    def self.ensure_badge(name, attrs)
      badge = Badge.find_by("name ILIKE ?", name)

      # Check for letter-case differences
      badge.update!(name: name) if badge && badge.name != name

      badge || Badge.create!(name: name, **attrs)
    end

    def self.contributor_badges
      bronze =
        ensure_badge(
          BADGE_NAME_BRONZE,
          description: "Contributed an accepted pull request",
          badge_type_id: 3,
          default_icon: "fab-git-alt",
        )

      silver =
        ensure_badge(
          BADGE_NAME_SILVER,
          description: "Contributed 25 accepted pull requests",
          badge_type_id: 2,
          default_icon: "fab-git-alt",
        )

      gold =
        ensure_badge(
          BADGE_NAME_GOLD,
          description: "Contributed 250 accepted pull requests",
          badge_type_id: 1,
          default_icon: "fab-git-alt",
        )

      [bronze, silver, gold]
    end

    def self.committer_badges
      bronze =
        ensure_badge(
          COMMITTER_BADGE_NAME_BRONZE,
          description: "Created a commit",
          enabled: false,
          badge_type_id: 3,
        )

      silver =
        ensure_badge(
          COMMITTER_BADGE_NAME_SILVER,
          description: "Created 25 commits",
          enabled: false,
          badge_type_id: 2,
        )

      gold =
        ensure_badge(
          COMMITTER_BADGE_NAME_GOLD,
          description: "Created 1000 commits",
          enabled: false,
          badge_type_id: 1,
        )

      [bronze, silver, gold]
    end
  end
end
