# frozen_string_literal: true

require "tty-prompt"
require_relative "../release_utils/version"

module ReleaseUtils
  PRIMARY_RELEASE_TAG = "release"
  RELEASE_TAGS = [PRIMARY_RELEASE_TAG, "beta", "latest-release"].freeze
  PRIMARY_ESR_TAG = "esr"
  ESR_TAGS = [PRIMARY_ESR_TAG, "stable"].freeze
  PR_LABEL = "release"

  def self.dry_run?
    !!ENV["DRY_RUN"]
  end

  def self.test_mode?
    ENV["RUNNING_RELEASE_IN_RSPEC_TESTS"] == "1"
  end

  def self.read_versions_json
    ReleaseUtils.with_clean_worktree("main") { JSON.parse(File.read("versions.json")) }
  end

  def self.released_versions
    read_versions_json
      .select { |_version, info| info["released"] }
      .keys
      .sort_by { |v| Gem::Version.new(v) }
  end

  def self.released_esrs
    read_versions_json
      .select { |_version, info| info["released"] && info["esr"] }
      .keys
      .sort_by { |v| Gem::Version.new(v) }
  end

  def self.read_version_rb
    File.read("lib/version.rb")
  end

  def self.write_version(version)
    File.write("lib/version.rb", read_version_rb.sub(/STRING = ".*"/, "STRING = \"#{version}\""))
  end

  def self.update_versions_json(new_version)
    today_date = DateTime.now.utc.strftime("%Y-%m-%d")

    version_year, version_month = new_version.split(".").map(&:to_i)
    esr = [1, 7].include?(version_month)

    support_period = esr ? 8.months : 2.months
    support_end_date = (Date.new(version_year, version_month, 1) + support_period).strftime("%Y-%m")

    new_version_info = {
      new_version => {
        developmentStartDate: today_date,
        releaseDate: "#{version_year}-#{version_month.to_s.rjust(2, "0")}",
        supportEndDate: support_end_date,
        released: false,
        esr: esr,
        supported: true,
      },
    }

    data = JSON.parse(File.read("versions.json"))
    data.transform_values! do |v|
      if !v["released"]
        v["released"] = true
        v["releaseDate"] = today_date
      end

      if v["supported"] &&
           Date.parse(v["supportEndDate"] + "-01") < Date.new(version_year, version_month, 1)
        v["supported"] = false
        v["supportEndDate"] = today_date
      end

      v
    end

    File.write("versions.json", JSON.pretty_generate({ **new_version_info, **data }) + "\n")
  end

  def self.git(*args, allow_failure: false, silent: false)
    puts "> git #{args.inspect}" unless silent
    stdout, stderr, status = Open3.capture3({ "LEFTHOOK" => "0" }, "git", *args)
    if !status.success? && !allow_failure
      raise "Command failed: git #{args.inspect}\n#{stdout.indent(2)}\n#{stderr.indent(2)}"
    end
    stdout
  end

  def self.gh(*args)
    puts "> gh #{args.inspect}"
    return true if test_mode?
    system "gh", *args
  end

  def self.ref_exists?(ref)
    git "rev-parse", "--verify", ref
    true
  rescue StandardError
    false
  end

  def self.confirm(msg)
    return true if test_mode?
    TTY::Prompt.new.yes?(msg)
  end

  def self.confirm_or_abort(msg)
    return if test_mode?
    raise "Aborted" unless confirm(msg)
  end

  def self.merge_pr(base:, branch:)
    if dry_run?
      puts "[DRY RUN] Skipping merge of #{branch}"
      return
    end

    loop do
      confirm_or_abort "Ready to merge #{branch}?"

      if test_mode?
        git "push", "origin", "#{branch}:#{base}"
        break
      else
        success = gh("pr", "merge", branch, "--rebase", "--delete-branch")
        break if success
        puts "Merge failed. Maybe the PR isn't approved yet, or there's a conflict."
      end
    end

    puts "Merge successful"
  end

  def self.make_pr(base:, branch:, title: nil, body: nil, draft: false)
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

  def self.with_clean_worktree(origin_branch)
    git "fetch", "origin", origin_branch
    path = "#{Rails.root}/tmp/version-bump-worktree-#{SecureRandom.hex}"
    begin
      FileUtils.mkdir_p(path)
      git "worktree", "add", path, "origin/#{origin_branch}"
      Dir.chdir(path) { yield } # rubocop:disable Discourse/NoChdir
    ensure
      puts "Cleaning up temporary worktree..."
      git "worktree", "remove", "--force", path, silent: true, allow_failure: true
      FileUtils.rm_rf(path)
    end
  end
end

namespace :release do
  desc "Check a commit hash and create a release branch if it's a trigger"
  task "maybe_cut_branch", [:check_ref] do |t, args|
    check_ref = args[:check_ref]

    new_version = nil
    previous_version = nil

    ReleaseUtils.with_clean_worktree("main") do
      ReleaseUtils.git("checkout", check_ref.to_s)
      new_version = ReleaseUtils::Version.current

      ReleaseUtils.git("checkout", "#{check_ref}^1")
      previous_version = ReleaseUtils::Version.current
    end

    raise "Unexpected previous version" if !previous_version.development?
    raise "Unexpected new version" if !new_version.development?

    next "version has not changed" if new_version.same_development_cycle?(previous_version)

    raise "New version is smaller than old version" if new_version < previous_version

    ReleaseUtils.git("branch", previous_version.branch_name, "#{check_ref}^1")
    puts "Created new branch #{previous_version.branch_name}"

    File.write(
      ENV["GITHUB_OUTPUT"] || "/dev/null",
      "new_branch_name=#{previous_version.branch_name}\n",
      mode: "a",
    )

    if ReleaseUtils.dry_run?
      puts "[DRY RUN] Skipping pushing branch #{previous_version.branch_name} to origin"
    else
      ReleaseUtils.git("push", "--set-upstream", "origin", previous_version.branch_name)
      puts "Pushed branch #{previous_version.branch_name} to origin"
    end

    puts "Done!"
  end

  desc "Maybe tag release"
  task "maybe_tag_release", [:check_ref] do |t, args|
    check_ref = args[:check_ref]

    current_version =
      ReleaseUtils.with_clean_worktree("main") do
        ReleaseUtils.git "checkout", check_ref.to_s
        release_branches =
          ReleaseUtils
            .git("branch", "-a", "--contains", check_ref, "release/*", "main")
            .lines
            .map(&:strip)
        if release_branches.empty?
          puts "Commit #{check_ref} is not on a release branch. Skipping"
          next
        end

        ReleaseUtils::Version.current
      end
    next unless current_version

    if ReleaseUtils.ref_exists?(current_version.tag_name)
      puts "Tag #{current_version.tag_name} already exists, skipping"
    else
      puts "Tagging release #{current_version.tag_name}"
      ReleaseUtils.git "tag", "-a", current_version.tag_name, "-m", "version #{current_version}"

      if ReleaseUtils.dry_run?
        puts "[DRY RUN] Skipping pushing tag to origin"
      else
        ReleaseUtils.git "push", "origin", "refs/tags/#{current_version.tag_name}"
      end
    end

    puts "Done!"
  end

  desc "Update release/beta/latest-release tags to track latest release"
  task "update_release_tags", [:check_ref] do |t, args|
    check_ref = args[:check_ref]

    current_version =
      ReleaseUtils.with_clean_worktree("main") do
        ReleaseUtils.git "checkout", check_ref.to_s
        ReleaseUtils::Version.current
      end

    released_versions = ReleaseUtils.released_versions.map(&ReleaseUtils::Version.method(:new))

    if released_versions.empty? || current_version >= released_versions.last
      ReleaseUtils::RELEASE_TAGS.each do |synonym_tag|
        message =
          if synonym_tag == ReleaseUtils::PRIMARY_RELEASE_TAG
            "latest release"
          else
            "backwards-compatibility alias for `#{ReleaseUtils::PRIMARY_RELEASE_TAG}` tag"
          end
        ReleaseUtils.git "tag", "-a", synonym_tag, "-m", message, "-f"
      end
      if ReleaseUtils.dry_run?
        puts "[DRY RUN] Skipping pushing #{ReleaseUtils::RELEASE_TAGS.inspect} tags to origin"
      else
        ReleaseUtils.git "push",
                         "origin",
                         "-f",
                         *ReleaseUtils::RELEASE_TAGS.map { |tag| "refs/tags/#{tag}" }
      end
    else
      puts "Current version #{current_version} is older than latest release #{released_versions.last}. Skipping."
    end

    # Update ESR tags if this version is in the latest released ESR series
    released_esrs = ReleaseUtils.released_esrs.map(&ReleaseUtils::Version.method(:new))
    if released_esrs.any? && current_version.same_series?(released_esrs.last)
      ReleaseUtils::ESR_TAGS.each do |synonym_tag|
        message =
          if synonym_tag == ReleaseUtils::PRIMARY_ESR_TAG
            "latest ESR release"
          else
            "backwards-compatibility alias for `#{ReleaseUtils::PRIMARY_ESR_TAG}` tag"
          end
        ReleaseUtils.git "tag", "-a", synonym_tag, "-m", message, "-f"
      end
      if ReleaseUtils.dry_run?
        puts "[DRY RUN] Skipping pushing #{ReleaseUtils::ESR_TAGS.inspect} tags to origin"
      else
        ReleaseUtils.git "push",
                         "origin",
                         "-f",
                         *ReleaseUtils::ESR_TAGS.map { |tag| "refs/tags/#{tag}" }
      end
    end

    puts "Done!"
  end

  desc "Prepare a version bump PR for `main`"
  task "prepare_next_version" do |t, args|
    pr_branch_name = "version-bump/main"
    branch = "main"

    ReleaseUtils.with_clean_worktree(branch) do
      ReleaseUtils.git "branch", "-D", pr_branch_name if ReleaseUtils.ref_exists?(pr_branch_name)
      ReleaseUtils.git "checkout", "-b", pr_branch_name

      current_version = ReleaseUtils::Version.current
      target_version = ReleaseUtils::Version.next

      ReleaseUtils.write_version(target_version)
      ReleaseUtils.update_versions_json(target_version.series)
      ReleaseUtils.git "add", "lib/version.rb", "versions.json"
      ReleaseUtils.git "commit",
                       "-m",
                       "DEV: Begin development of v#{target_version}\n\nMerging this will trigger the creation of a `#{current_version.branch_name}` branch on the preceding commit."
    end

    if ReleaseUtils.dry_run?
      puts "[DRY RUN] Skipping pushing & PR for branch #{pr_branch_name}"
    else
      ReleaseUtils.git "push", "-f", "--set-upstream", "origin", pr_branch_name
      ReleaseUtils.make_pr(base: branch, branch: pr_branch_name)
      puts "Done! Branch #{pr_branch_name} has been pushed to origin and a pull request has been created."
    end
  end

  desc <<~DESC
    Stage security fixes from private-mirror PRs into a single branch for review/merge.
    Fetches open PRs from private-mirror and presents an interactive selection.
    e.g.
      bin/rake "release:stage_security_fixes[main]"
      bin/rake "release:stage_security_fixes[release/2025.11]"
  DESC
  task "stage_security_fixes", [:base] do |t, args|
    base = args[:base]
    if !base.start_with?("release/") && !%w[stable main].include?(base)
      raise "Unknown base: #{base.inspect}"
    end

    fix_refs = ENV["SECURITY_FIX_REFS"]&.split(",")&.map(&:strip)
    private_mirror_pr_numbers = []

    if fix_refs.nil? || fix_refs.empty?
      json_output, status =
        Open3.capture2(
          "gh",
          "pr",
          "list",
          "--repo",
          "discourse/discourse-private-mirror",
          "--base",
          base,
          "--state",
          "open",
          "--json",
          "number,title,headRefName",
          "--limit",
          "100",
        )
      raise "Failed to fetch PRs from private-mirror" if !status.success?

      prs = JSON.parse(json_output)
      raise "No open PRs found targeting #{base} on private-mirror" if prs.empty?

      prompt = TTY::Prompt.new
      choices =
        prs.map do |pr|
          { name: "##{pr["number"]}: #{pr["title"]}", value: pr.slice("number", "headRefName") }
        end

      selected =
        prompt.multi_select(
          "Select security fix PRs to include (space to toggle, enter to finish):",
          choices,
          default: [],
          per_page: choices.size,
        )
      raise "No PRs selected" if selected.empty?

      fix_refs = selected.map { |pr| "privatemirror/#{pr["headRefName"]}" }
      private_mirror_pr_numbers = selected.map { |pr| pr["number"] }
    end

    puts "Staging security fixes for #{base} branch: #{fix_refs.inspect}"

    branch = "security/#{base}-security-fixes"

    ReleaseUtils.with_clean_worktree(base) do
      ReleaseUtils.git "branch", "-D", branch if ReleaseUtils.ref_exists?(branch)
      ReleaseUtils.git "checkout", "-b", branch

      fix_refs.each do |ref|
        origin, origin_branch = ref.split("/", 2)
        ReleaseUtils.git "fetch", origin, origin_branch

        first_commit_on_branch =
          ReleaseUtils.git("log", "--format=%H", "origin/#{base}..#{ref}").lines.last.strip
        ReleaseUtils.git "cherry-pick", "#{first_commit_on_branch}^..#{ref}"
      end

      if base == "main" &&
           ReleaseUtils.confirm(
             "Bump the `latest` branch revision to #{ReleaseUtils::Version.current.next_revision}? This should only be done for security-fix merges which are not part of a regular monthly release.",
           )
        new_version = ReleaseUtils::Version.current.next_revision
        ReleaseUtils.write_version(new_version)
        ReleaseUtils.git "add", "lib/version.rb"
        ReleaseUtils.git "commit", "-m", "DEV: Bump development branch to v#{new_version}"
      end

      puts "Finished merging commits into a locally-staged #{branch} branch. Git log is:"
      puts ReleaseUtils.git("log", "origin/#{base}..#{branch}")

      ReleaseUtils.confirm_or_abort "Check the log above. Ready to push this branch to the origin and create a PR?"
      ReleaseUtils.git("push", "-f", "--set-upstream", "origin", branch)

      ReleaseUtils.make_pr(
        base: base,
        branch: branch,
        title: "Security fixes for #{base}",
        body: <<~MD,
          > :warning: This PR should not be merged via the GitHub web interface
          >
          > It should only be merged using the associated `bin/rake release:stage_security_fixes` task.
        MD
        draft: true,
      )
      puts "Do not merge the PR via the GitHub web interface. Get it approved, then come back here to continue."
      ReleaseUtils.merge_pr(base: base, branch: branch)
    end

    if private_mirror_pr_numbers.any?
      puts "Closing associated PRs in private-mirror..."
      private_mirror_pr_numbers.each do |pr_number|
        ReleaseUtils.gh(
          "pr",
          "close",
          pr_number.to_s,
          "--repo",
          "discourse/discourse-private-mirror",
          "--delete-branch",
        )
      end
    end
  end
end
