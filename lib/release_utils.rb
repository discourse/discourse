# frozen_string_literal: true

require "open3"
require_relative "release_utils/version"

module ReleaseUtils
  PRIMARY_RELEASE_TAG = "release"
  RELEASE_TAGS = [PRIMARY_RELEASE_TAG, "beta", "latest-release"].freeze
  PRIMARY_ESR_TAG = "esr"
  ESR_TAGS = [PRIMARY_ESR_TAG, "stable"].freeze
  PR_LABEL = "release"

  class << self
    def dry_run?
      !!ENV["DRY_RUN"]
    end

    def test_mode?
      ENV["RUNNING_RELEASE_IN_RSPEC_TESTS"] == "1"
    end

    def read_versions_json
      ReleaseUtils.with_clean_worktree("main") { JSON.parse(File.read("versions.json")) }
    end

    def released_versions
      read_versions_json
        .select { |_version, info| info["released"] }
        .keys
        .sort_by { |v| Gem::Version.new(v) }
    end

    def released_esrs
      read_versions_json
        .select { |_version, info| info["released"] && info["esr"] }
        .keys
        .sort_by { |v| Gem::Version.new(v) }
    end

    def read_version_rb
      File.read("lib/version.rb")
    end

    def write_version(version)
      File.write("lib/version.rb", read_version_rb.sub(/STRING = ".*"/, "STRING = \"#{version}\""))
    end

    def commit_version_bump(version, message)
      write_version(version)
      git "add", "lib/version.rb"
      git "commit", "-m", message
    end

    def last_tuesday_of_month(date)
      date.beginning_of_month.next_month.prev_occurring(:tuesday)
    end

    def update_versions_json(new_version)
      today = Date.current.to_s

      version_year, version_month = new_version.split(".").map(&:to_i)
      version_start = Date.new(version_year, version_month)
      esr = version_month.in?([1, 7])

      new_version_info = {
        new_version => {
          developmentStartDate: today,
          releaseDate: last_tuesday_of_month(version_start).to_s,
          supportEndDate: last_tuesday_of_month(version_start + (esr ? 8.months : 2.months)).to_s,
          released: false,
          esr:,
          supported: true,
        },
      }

      data = JSON.parse(File.read("versions.json"))
      data.transform_values! do |v|
        if !v["released"]
          v["released"] = true
          v["releaseDate"] = today
        end

        if v["supported"] && Date.parse(v["supportEndDate"]) < version_start
          v["supported"] = false
          v["supportEndDate"] = today
        end

        v
      end

      File.write("versions.json", JSON.pretty_generate({ **new_version_info, **data }) + "\n")
    end

    def git(*args, allow_failure: false, silent: false)
      puts "> git #{args.inspect}" unless silent
      stdout, stderr, status = Open3.capture3({ "LEFTHOOK" => "0" }, "git", *args)
      if !status.success? && !allow_failure
        raise "Command failed: git #{args.inspect}\n#{stdout.indent(2)}\n#{stderr.indent(2)}"
      end
      stdout
    end

    def gh(*args, capture: false, input: nil)
      puts "> gh #{args.inspect}"
      return true if test_mode? && !capture

      if capture
        stdout_text, stderr_text, status = Open3.capture3("gh", *args, stdin_data: input)

        return stdout_text if status.success?

        raise <<~MESSAGE
        gh failed with status #{status.exitstatus}
        Command: gh #{args.join(" ")}
        STDOUT:
        #{stdout_text}
        STDERR:
        #{stderr_text}
      MESSAGE
      else
        system "gh", *args
      end
    end

    def supported_version_info
      read_versions_json.select { |_version, info| info["supported"] }
    end

    def ref_exists?(ref)
      git "rev-parse", "--verify", ref
      true
    rescue StandardError
      false
    end

    def confirm(msg)
      return true if test_mode?
      TTY::Prompt.new.yes?(msg)
    end

    def confirm_or_abort(msg)
      return if test_mode?
      raise "Aborted" unless confirm(msg)
    end

    def merge_pr(base:, branch:)
      if dry_run?
        puts "[DRY RUN] Skipping merge of #{branch}"
        return
      end

      loop do
        confirm_or_abort "Ready to merge #{branch}?"

        if test_mode?
          git "push", "origin", "HEAD:#{base}"
          break
        else
          if !gh("pr", "ready", branch) # remove draft status
            puts "Failed to mark PR as ready-for-review... trying to merge anyway"
          end
          success = gh("pr", "merge", branch, "--rebase", "--delete-branch")
          break if success
          puts "Merge failed. Maybe the PR isn't approved yet, or there's a conflict."
        end
      end

      puts "Merge successful"
    end

    def make_pr(base:, branch:, title: nil, body: nil, draft: false)
      title ||= git("log", "-1", branch, "--pretty=%s").strip
      body ||= git("log", "-1", branch, "--pretty=%b").strip

      title_and_body = ["--title", title, "--body", body]
      draft_flag = draft ? ["--draft"] : []

      success =
        gh(
          "pr",
          "create",
          "--base",
          base,
          "--head",
          branch,
          *title_and_body,
          *draft_flag,
          "--label",
          PR_LABEL,
        ) || gh("pr", "edit", branch, *title_and_body, "--add-label", PR_LABEL)

      raise "Failed to create or update PR" unless success
    end

    def with_clean_worktree(origin_branch)
      git "fetch", "origin", origin_branch
      path = "#{Rails.root.join("tmp/version-bump-worktree-#{SecureRandom.hex}")}"
      begin
        FileUtils.mkdir_p(path)
        git "worktree", "add", "--detach", path, "origin/#{origin_branch}"
        Dir.chdir(path) { yield } # rubocop:disable Discourse/NoChdir
      ensure
        puts "Cleaning up temporary worktree..."
        git "worktree", "remove", "--force", path, silent: true, allow_failure: true
        FileUtils.rm_rf(path)
      end
    end
  end
end
