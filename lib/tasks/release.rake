# frozen_string_literal: true

module ReleaseUtils
  def self.dry_run?
    !!ENV["DRY_RUN"]
  end

  def self.test_mode?
    ENV["RUNNING_RELEASE_IN_RSPEC_TESTS"] == "1"
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

  def self.git(*args, allow_failure: false, silent: false)
    puts "> git #{args.inspect}" unless silent
    stdout, stderr, status = Open3.capture3({ "LEFTHOOK" => "0" }, "git", *args)
    if !status.success? && !allow_failure
      raise "Command failed: git #{args.inspect}\n#{stdout.indent(2)}\n#{stderr.indent(2)}"
    end
    stdout
  end

  def self.ref_exists?(ref)
    git "rev-parse", "--verify", ref
    true
  rescue StandardError
    false
  end

  def self.make_pr(base:, branch:)
    return if test_mode?

    args = ["--title", `git log -1 --pretty=%s`.strip, "--body", `git log -1 --pretty=%b`.strip]

    success =
      system("gh", "pr", "create", "--base", base, "--head", branch, *args) ||
        system("gh", "pr", "edit", branch, *args)

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

    ReleaseUtils.with_clean_worktree("main") do
      ReleaseUtils.git("checkout", check_ref.to_s)
      new_version = ReleaseUtils.parse_current_version

      ReleaseUtils.git("checkout", "#{check_ref}^1")
      previous_version = ReleaseUtils.parse_current_version

      next "version has not changed" if new_version == previous_version

      raise "Unexpected previous version" if !previous_version.ends_with? "-latest"
      raise "Unexpected new version" if !new_version.ends_with? "-latest"
      if Gem::Version.new(new_version) < Gem::Version.new(previous_version)
        raise "New version is smaller than old version"
      end

      parts = previous_version.split(".")
      new_branch_name = "release/#{parts[0]}.#{parts[1]}"

      ReleaseUtils.git("branch", new_branch_name)
      puts "Created new branch #{new_branch_name}"

      File.write(
        ENV["GITHUB_OUTPUT"] || "/dev/null",
        "new_branch_name=#{new_branch_name}\n",
        mode: "a",
      )
    end

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

    existing_releases =
      ReleaseUtils
        .git("tag", "-l", "v*")
        .lines
        .map { |tag| Gem::Version.new(tag.strip.delete_prefix("v")) }
        .sort

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

      if existing_releases.last && Gem::Version.new(current_version) > existing_releases.last
        ReleaseUtils.git "tag", "-a", "release", "-m", "latest release"
        if ReleaseUtils.dry_run?
          puts "[DRY RUN] Skipping pushing 'release' tag to origin"
        else
          ReleaseUtils.git "push", "origin", "-f", "refs/tags/release"
        end
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

      target_version_number = "#{Time.now.strftime("%Y.%m")}.0-latest"

      if Gem::Version.new(target_version_number) <= Gem::Version.new(current_version)
        puts "Target version #{current_version} is already >= #{target_version_number}. Incrementing instead."
        major, minor, patch_and_pre = current_version.split(".")
        minor = (minor.to_i + 1).to_s.rjust(2, "0")
        target_version_number = "#{major}.#{minor}.#{patch_and_pre}"
      end

      ReleaseUtils.write_version(target_version_number)
      ReleaseUtils.git "add", "lib/version.rb"
      ReleaseUtils.git "commit",
                       "-m",
                       "DEV: Begin development of v#{target_version_number}\n\nMerging this will trigger the creation of a `release/#{current_version.sub(".0-latest", "")}` branch on the preceding commit."
    end

    ReleaseUtils.git "push", "-f", "--set-upstream", "origin", pr_branch_name

    ReleaseUtils.make_pr(base: branch, branch: pr_branch_name)

    puts "Done! Branch #{pr_branch_name} has been pushed to origin and a pull request has been created."
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
end
