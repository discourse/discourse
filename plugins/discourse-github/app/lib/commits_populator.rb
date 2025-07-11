# frozen_string_literal: true

module DiscourseGithubPlugin
  class CommitsPopulator
    MERGE_COMMIT_REGEX = /^Merge pull request/
    HISTORY_COMPLETE = "history-complete"
    class GraphQLError < StandardError
    end

    ROLES = { committer: 0, contributor: 1 }

    class PaginatedCommits
      def initialize(octokit, repo, cursor: nil, page_size: 100)
        @client = octokit
        @repo = repo
        @cursor = cursor
        @page_size = page_size
        raise ArgumentError, "page_size arg must be <= 100" if page_size > 100
        if cursor && !cursor.match?(/^\h{40}\s(\d+)$/)
          raise ArgumentError,
                "cursor must be a 40-characters hex string followed by a space and a number"
        end
        fetch_commits
      end

      def next
        cursor = next_cursor
        return unless cursor
        PaginatedCommits.new(@client, @repo, cursor: cursor, page_size: @page_size)
      end

      def commits
        @data.repository.defaultBranchRef.target.history.nodes
      end

      def next_cursor
        info = @data.repository.defaultBranchRef.target.history.pageInfo
        return unless info.hasNextPage
        info.endCursor
      end

      private

      def fetch_commits
        owner, name = @repo.name.split("/", 2)
        history_args = "first: #{@page_size}"
        history_args += ", after: #{@cursor.inspect}" if @cursor

        query = <<~QUERY
          query {
            repository(name: #{name.inspect}, owner: #{owner.inspect}) {
              defaultBranchRef {
                target {
                  ... on Commit {
                    history(#{history_args}) {
                      pageInfo {
                        endCursor
                        hasNextPage
                      }
                      nodes {
                        oid
                        message
                        committedDate
                        associatedPullRequests(first: 1) {
                          nodes {
                            author {
                              login
                            }
                            mergedBy {
                              login
                            }
                          }
                        }
                        author {
                          email
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        QUERY
        response = @client.post("/graphql", { query: query }.to_json)
        raise GraphQLError, response.errors.inspect if response.errors
        raise GraphQLError, response.message if !response.data
        @data = response.data
      end
    end

    def initialize(repo)
      @repo = repo
      @client =
        Octokit::Client.new(access_token: SiteSetting.github_linkback_access_token, per_page: 100)
    end

    def populate!
      return unless SiteSetting.github_badges_enabled?
      return if @client.branches(@repo.name).empty?

      if @repo.commits.size == 0
        build_history!
      else
        front_sha = Discourse.redis.get(front_commit_redis_key)
        if front_sha.present? && removed?(front_sha)
          # there has been a force push, next run will rebuild history
          @repo.commits.delete_all
          Discourse.redis.del(back_cursor_redis_key)
          Discourse.redis.del(front_commit_redis_key)
          return
        end
        fetch_new_commits!(front_sha)
        front_sha = Discourse.redis.get(front_commit_redis_key)
        @repo.reload

        back_cursor = Discourse.redis.get(back_cursor_redis_key)
        return if back_cursor == HISTORY_COMPLETE
        if back_cursor.present?
          build_history!(cursor: back_cursor)
        elsif front_sha.present?
          count = @repo.commits.count
          build_history!(cursor: "#{front_sha} #{count - 1}")
        else
          # this is a bad state that we should never be in
          # But in case it happens, easiest way to recover
          # is to start from scratch.
          @repo.commits.delete_all
          Discourse.redis.del(back_cursor_redis_key)
          Discourse.redis.del(front_commit_redis_key)
        end
      end
    rescue Octokit::Error => err
      case err
      when Octokit::NotFound
        disable_github_badges_and_inform_admin(
          title: I18n.t("github_commits_populator.errors.repository_not_found_pm_title"),
          raw:
            I18n.t(
              "github_commits_populator.errors.repository_not_found_pm",
              repo_name: @repo.name,
              base_path: Discourse.base_path,
            ),
        )
        Rails.logger.warn(
          "Disabled github_badges_enabled site setting due to repository Not Found error ",
        )
      when Octokit::Unauthorized
        disable_github_badges_and_inform_admin(
          title: I18n.t("github_commits_populator.errors.invalid_octokit_credentials_pm_title"),
          raw:
            I18n.t(
              "github_commits_populator.errors.invalid_octokit_credentials_pm",
              base_path: Discourse.base_path,
            ),
        )
        Rails.logger.warn(
          "Disabled github_badges_enabled site setting due to invalid GitHub authentication credentials via github_linkback_access_token.",
        )
      else
        Rails.logger.warn("#{err.class}: #{err.message}")
      end
    rescue Octokit::InvalidRepository => err
      disable_github_badges_and_inform_admin(
        title: I18n.t("github_commits_populator.errors.repository_identifier_invalid_pm_title"),
        raw:
          I18n.t(
            "github_commits_populator.errors.repository_identifier_invalid_pm",
            repo_name: @repo.name,
            base_path: Discourse.base_path,
          ),
      )
      Rails.logger.warn(
        "Disabled github_badges_enabled site setting due to invalid repository identifier",
      )
    end

    private

    def is_contribution?(commit)
      pr = commit.associatedPullRequests.nodes.first
      pr && pr.author && pr.mergedBy && pr.author.login != pr.mergedBy.login
    end

    def fetch_new_commits!(stop_at)
      paginator = PaginatedCommits.new(@client, @repo, page_size: 10)
      batch = paginator.commits
      done = false
      commits = []
      recent_commits =
        stop_at.present? ? [] : @repo.commits.order("committed_at DESC").first(100).pluck(:sha)
      while !done
        batch.each do |c|
          if c.oid == stop_at || recent_commits.include?(c.oid)
            done = true
            break
          end
          commits << c
        end
        break if done
        paginator = paginator.next
        batch = paginator&.commits || []
        break if batch.empty?
      end
      return if commits.size == 0
      existing_shas = @repo.commits.pluck(:sha)
      commits.reject! { |c| existing_shas.include?(c.oid) }
      batch_to_db(commits)
      set_front_commit(commits.first.oid)
    end

    # detect if a force push happened and commit is lost
    def removed?(sha)
      commit = @client.commit(@repo.name, sha)
      return true if commit.commit.nil?
      found =
        @client.commits(@repo.name, until: commit.commit.committer.date, page: 1, per_page: 1).first
      commit.sha != found.sha
    end

    def build_history!(cursor: nil)
      paginator = PaginatedCommits.new(@client, @repo, cursor: cursor, page_size: 100)
      batch = paginator.commits
      return if batch.empty?
      set_front_commit(batch.first.oid) if cursor.blank?

      while batch.size > 0
        batch_to_db(batch)
        next_cursor = paginator.next_cursor
        set_back_cursor(next_cursor) if next_cursor

        paginator = paginator.next
        batch = paginator&.commits || []
      end
      set_back_cursor(HISTORY_COMPLETE)
    end

    def batch_to_db(batch)
      fragments = []
      batch.each do |c|
        hash = commit_to_hash(c)
        fragments << DB.sql_fragment(<<~SQL, hash)
          (:repo_id, :sha, :email, :committed_at, :role_id, :merge_commit, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        SQL
      end
      DB.exec(<<~SQL)
        INSERT INTO github_commits
        (repo_id, sha, email, committed_at, role_id, merge_commit, created_at, updated_at) VALUES #{fragments.join(",")}
      SQL
    end

    def commit_to_hash(commit)
      {
        sha: commit.oid,
        email: commit.author.email,
        repo_id: @repo.id,
        committed_at: commit.committedDate,
        merge_commit: commit.message.match?(MERGE_COMMIT_REGEX),
        role_id: is_contribution?(commit) ? ROLES[:contributor] : ROLES[:committer],
      }
    end

    def set_front_commit(sha)
      Discourse.redis.set(front_commit_redis_key, sha)
    end

    def set_back_cursor(cursor)
      Discourse.redis.set(back_cursor_redis_key, cursor)
    end

    def front_commit_redis_key
      # this key should refer to the MOST RECENT commit we have in the db
      "discourse-github-front-commit-#{@repo.name}"
    end

    def back_cursor_redis_key
      # this key should refer to the cursor that lets us continue
      # building history from the point we reached in the previous run
      # that couldn't continue for whatever reasons
      # e.g., if we got rate-limited by github
      "discourse-github-back-cursor-#{@repo.name}"
    end

    def disable_github_badges_and_inform_admin(title:, raw:)
      SiteSetting.github_badges_enabled = false
      site_admin_usernames =
        User.where(admin: true).human_users.order("last_seen_at DESC").limit(10).pluck(:username)
      PostCreator.create!(
        Discourse.system_user,
        title: title,
        raw: raw,
        archetype: Archetype.private_message,
        target_usernames: site_admin_usernames,
        skip_validations: true,
      )
    end
  end
end
