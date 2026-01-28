# frozen_string_literal: true

require "tty-prompt"

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

  def self.parse_current_version
    version = read_version_rb[/STRING = "(.*)"/, 1]
    raise "Unable to parse current version" if version.nil?
    puts "Parsed current version: #{version.inspect}"
    version
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
    return if test_mode?
    prompt = TTY::Prompt.new
    raise "Aborted" unless prompt.yes?(msg)
  end

  def self.merge_pr(base:, branch:)
    if dry_run?
      puts "[DRY RUN] Skipping merge of #{branch}"
      return
    end

    loop do
      confirm "Ready to merge #{branch}?"

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

    new_branch_name = nil
    new_version = nil
    previous_version = nil

    ReleaseUtils.with_clean_worktree("main") do
      ReleaseUtils.git("checkout", check_ref.to_s)
      new_version = ReleaseUtils.parse_current_version

      ReleaseUtils.git("checkout", "#{check_ref}^1")
      previous_version = ReleaseUtils.parse_current_version
    end

    next "version has not changed" if new_version == previous_version

    raise "Unexpected previous version" if !previous_version.ends_with? "-latest"
    raise "Unexpected new version" if !new_version.ends_with? "-latest"
    if Gem::Version.new(new_version) < Gem::Version.new(previous_version)
      raise "New version is smaller than old version"
    end

    parts = previous_version.split(".")
    new_branch_name = "release/#{parts[0]}.#{parts[1]}"

    ReleaseUtils.git("branch", new_branch_name, "#{check_ref}^1")
    puts "Created new branch #{new_branch_name}"

    File.write(
      ENV["GITHUB_OUTPUT"] || "/dev/null",
      "new_branch_name=#{new_branch_name}\n",
      mode: "a",
    )

    if ReleaseUtils.dry_run?
      puts "[DRY RUN] Skipping pushing branch #{new_branch_name} to origin"
    else
      ReleaseUtils.git("push", "--set-upstream", "origin", new_branch_name)
      puts "Pushed branch #{new_branch_name} to origin"
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

        ReleaseUtils.parse_current_version
      end

    tag_name = "v#{current_version}"

    if ReleaseUtils.ref_exists?(tag_name)
      puts "Tag #{tag_name} already exists, skipping"
    else
      puts "Tagging release #{tag_name}"
      ReleaseUtils.git "tag", "-a", tag_name, "-m", "version #{current_version}"

      if ReleaseUtils.dry_run?
        puts "[DRY RUN] Skipping pushing tag to origin"
      else
        ReleaseUtils.git "push", "origin", "refs/tags/#{tag_name}"
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
        ReleaseUtils.parse_current_version
      end

    released_versions = ReleaseUtils.released_versions
    current_minor = current_version.split(".").first(2).join(".") + ".0"
    current_minor_version = Gem::Version.new(current_minor)

    if released_versions.empty? || current_minor_version >= released_versions.last
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
    released_esrs = ReleaseUtils.released_esrs
    if released_esrs.any? && current_minor_version == released_esrs.last
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

      current_version = ReleaseUtils.parse_current_version

      target_version_number = "#{Time.now.strftime("%Y.%-m")}.0-latest"

      if Gem::Version.new(target_version_number) <= Gem::Version.new(current_version)
        puts "Target version #{current_version} is already >= #{target_version_number}. Incrementing instead."
        major, minor, patch_and_pre = current_version.split(".")
        minor = (minor.to_i + 1).to_s

        if minor.to_i > 12 && Time.now.month == 12
          major = (major.to_i + 1).to_s
          minor = "1"
        end

        target_version_number = "#{major}.#{minor}.#{patch_and_pre}"
      end

      ReleaseUtils.write_version(target_version_number)
      ReleaseUtils.update_versions_json(target_version_number.split(".").first(2).join("."))
      ReleaseUtils.git "add", "lib/version.rb", "versions.json"
      ReleaseUtils.git "commit",
                       "-m",
                       "DEV: Begin development of v#{target_version_number}\n\nMerging this will trigger the creation of a `release/#{current_version.sub(".0-latest", "")}` branch on the preceding commit."
    end

    if ReleaseUtils.dry_run?
      puts "[DRY RUN] Skipping pushing & PR for branch #{pr_branch_name}"
    else
      ReleaseUtils.git "push", "-f", "--set-upstream", "origin", pr_branch_name
      ReleaseUtils.make_pr(base: branch, branch: pr_branch_name)
      puts "Done! Branch #{pr_branch_name} has been pushed to origin and a pull request has been created."
    end
  end

  desc "Prepare version bump"
  task "prepare_next_version_branch", [:branch] do |t, args|
    branch = args[:branch]

    raise "Expected branch to start with 'release/'" if !branch.starts_with?("release/")

    pr_branch_name = "version-bump/#{args[:branch]}"

    ReleaseUtils.with_clean_worktree(branch) do
      ReleaseUtils.git "branch", "-D", pr_branch_name if ReleaseUtils.ref_exists?(pr_branch_name)
      ReleaseUtils.git "checkout", "-b", pr_branch_name

      current_version = ReleaseUtils.parse_current_version
      target_version_number =
        if current_version.end_with?("-latest")
          current_version.sub("-latest", "")
        else
          parts = current_version.split(".")
          "#{parts[0]}.#{parts[1]}.#{parts[2].to_i + 1}"
        end

      ReleaseUtils.write_version(target_version_number)
      ReleaseUtils.git "add", "lib/version.rb"
      ReleaseUtils.git "commit",
                       "-m",
                       "DEV: Bump version on `#{branch}` to `v#{target_version_number}`"
    end

    ReleaseUtils.git "push", "-f", "--set-upstream", "origin", pr_branch_name

    ReleaseUtils.make_pr(base: branch, branch: pr_branch_name)

    puts "Done! Branch #{pr_branch_name} has been pushed to origin and a pull request has been created."
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
        prs.map { |pr| { name: "##{pr["number"]}: #{pr["title"]}", value: pr["headRefName"] } }

      selected =
        prompt.multi_select(
          "Select security fix PRs to include (space to toggle, enter to finish):",
          choices,
          default: [],
          per_page: choices.size,
        )
      raise "No PRs selected" if selected.empty?

      fix_refs = selected.map { |branch| "privatemirror/#{branch}" }
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

      puts "Finished merging commits into a locally-staged #{branch} branch. Git log is:"
      puts ReleaseUtils.git("log", "origin/#{base}..#{branch}")

      ReleaseUtils.confirm "Check the log above. Ready to push this branch to the origin and create a PR?"
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
  end
end
