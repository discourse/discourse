# frozen_string_literal: true

require "tty-prompt"
require_relative "../release_utils"

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

    branch_name = previous_version.branch_name
    release_version = previous_version.release_version

    ReleaseUtils.with_clean_worktree("main") do
      ReleaseUtils.git("checkout", "#{check_ref}^1")
      ReleaseUtils.git("checkout", "-b", branch_name)

      ReleaseUtils.commit_version_bump(release_version, "DEV: Bump version to v#{release_version}")

      puts "Created new branch #{branch_name} with version #{release_version}"

      File.write(ENV["GITHUB_OUTPUT"] || "/dev/null", "new_branch_name=#{branch_name}\n", mode: "a")

      if ReleaseUtils.dry_run?
        puts "[DRY RUN] Skipping pushing branch #{branch_name} to origin"
      else
        ReleaseUtils.git("push", "--set-upstream", "origin", branch_name)
        puts "Pushed branch #{branch_name} to origin"
      end
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
    raise "Unknown base: #{base.inspect}" unless base.start_with?("release/") || base == "main"

    json_output =
      ReleaseUtils.gh(
        "pr",
        "list",
        "--repo",
        "discourse/discourse-private-mirror",
        "--base",
        base,
        "--state",
        "open",
        "--json",
        "number,title,body,headRefName",
        "--limit",
        "100",
        capture: true,
      )

    prs = JSON.parse(json_output)
    raise "No open PRs found targeting #{base} on private-mirror" if prs.empty?

    extract_ghsa_id = ->(body) do
      return nil if body.nil?
      match = body.match(%r{github\.com/discourse/discourse/security/advisories/(GHSA-[\w-]+)})
      match&.[](1)
    end

    choices =
      prs.map do |pr|
        pr.slice("number", "title", "body", "headRefName").merge(
          "ghsa_id" => extract_ghsa_id.call(pr["body"]),
        )
      end

    selected =
      if (ghsa_ids = ENV["SECURITY_FIX_GHSA_IDS"])
        requested = ghsa_ids.split(",").map(&:strip)
        choices.select { |pr| pr["ghsa_id"] && requested.include?(pr["ghsa_id"]) }
      else
        prompt = TTY::Prompt.new
        prompt_choices =
          choices.map do |pr|
            ghsa_label = pr["ghsa_id"] || "GHSA MISSING"
            { name: "##{pr["number"]} [#{ghsa_label}]: #{pr["title"]}", value: pr }
          end
        prompt.multi_select(
          "Select security fix PRs to include (space to toggle, enter to finish):",
          prompt_choices,
          default: [],
          per_page: prompt_choices.size,
        )
      end
    raise "No PRs selected" if selected.empty?

    puts "Staging security fixes for #{base} branch: #{selected.map { |pr| pr["headRefName"] }.inspect}"

    branch = "security/#{base}-security-fixes"

    ReleaseUtils.with_clean_worktree(base) do
      selected.each do |pr|
        ReleaseUtils.git "fetch", "privatemirror", pr["headRefName"]

        ReleaseUtils.git "merge", "--squash", "privatemirror/#{pr["headRefName"]}"

        commit_message = "#{pr["title"]}\n\n#{pr["body"]}".strip

        ReleaseUtils.git "commit", "-m", commit_message
      end

      if base == "main" &&
           ReleaseUtils.confirm(
             "Bump the `latest` branch revision to #{ReleaseUtils::Version.current.next_revision}? This should only be done for security-fix merges which are not part of a regular monthly release.",
           )
        new_version = ReleaseUtils::Version.current.next_revision
        ReleaseUtils.commit_version_bump(
          new_version,
          "DEV: Bump development branch to v#{new_version}",
        )
      elsif base.start_with?("release/")
        new_version = ReleaseUtils::Version.current.next_patch
        ReleaseUtils.commit_version_bump(new_version, "DEV: Bump release branch to v#{new_version}")
      end

      puts "Finished merging commits into a locally-staged branch. Git log is:"
      puts ReleaseUtils.git("log", "origin/#{base}..HEAD")

      ReleaseUtils.confirm_or_abort "Check the log above. Ready to push this branch to the origin and create a PR?"
      ReleaseUtils.git("push", "-f", "origin", "HEAD:refs/heads/#{branch}")

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

    if selected.any?
      puts "Closing associated PRs in private-mirror..."
      selected.each do |pr|
        ReleaseUtils.gh(
          "pr",
          "close",
          pr["number"].to_s,
          "--repo",
          "discourse/discourse-private-mirror",
          "--delete-branch",
        )
      end
    end
  end

  desc "Update advisory affected versions on GitHub for all supported Discourse versions"
  task "update_security_advisories" do
    advisories_base = "repos/discourse/discourse/security-advisories"

    puts "Fetching draft security advisories..."
    pages =
      JSON.parse(
        ReleaseUtils.gh(
          "api",
          "#{advisories_base}?state=draft",
          "--paginate",
          "--slurp",
          capture: true,
        ),
      )
    advisories = pages.flat_map { |page| page.is_a?(Array) ? page : [page] }

    draft_advisories =
      advisories.reject { |advisory| advisory.fetch("summary").start_with?("DRAFT") }

    if draft_advisories.empty?
      puts "No draft advisories to update."
      next
    end

    puts "Found #{draft_advisories.size} draft advisory(ies) to update."

    # Calculate patched versions for all supported versions
    version_patches = []
    version_info = ReleaseUtils.supported_version_info

    version_info.each do |series, info|
      branch = info["released"] ? "release/#{series}" : "main"

      current_version = ReleaseUtils.with_clean_worktree(branch) { ReleaseUtils::Version.current }

      if info["released"]
        # For released versions, next patch is current patch + 1
        next_version =
          "#{current_version.major}.#{current_version.minor}.#{current_version.patch + 1}"
        version_patches << { series:, patched_version: next_version }
        puts "  #{series}: #{current_version} -> #{next_version}"
      else
        # For unreleased (latest/development) version, ask about release type
        prompt = TTY::Prompt.new
        release_type =
          prompt.select(
            "What type of release for #{series} (currently #{current_version})?",
            {
              "Intermediate release (security patch)" => :intermediate,
              "Monthly release" => :monthly,
            },
          )

        next_version =
          if release_type == :intermediate
            current_version.next_revision.to_s
          else
            "#{current_version.major}.#{current_version.minor}.#{current_version.patch}"
          end

        version_patches << { series:, patched_version: next_version }
        puts "  #{series}: #{current_version} -> #{next_version} (#{release_type})"
      end
    end

    vulnerabilities =
      version_patches.map.with_index do |entry, index|
        vulnerable_range = index == 0 ? ">= 0" : ">= #{entry[:series]}.0-latest"
        {
          package: {
            ecosystem: "other",
            name: "Discourse",
          },
          vulnerable_version_range: vulnerable_range,
          patched_versions: entry[:patched_version],
        }
      end

    patched_versions = version_patches.map { |e| e[:patched_version] }
    puts "\nAdvisories to update:"
    draft_advisories.each { |a| puts "  - #{a.fetch("ghsa_id")}: #{a.fetch("summary")}" }
    puts "\nPatched versions: #{patched_versions.join(", ")}"

    ReleaseUtils.confirm_or_abort("Proceed with updating #{draft_advisories.size} advisory(ies)?")

    draft_advisories.each do |advisory|
      ghsa_id = advisory.fetch("ghsa_id")
      payload = { vulnerabilities: vulnerabilities }

      ReleaseUtils.gh(
        "api",
        "#{advisories_base}/#{ghsa_id}",
        "--method",
        "PATCH",
        "--input",
        "-",
        capture: true,
        input: JSON.pretty_generate(payload),
      )

      puts "Updated #{ghsa_id}"
    end

    puts "\nDone! Updated #{draft_advisories.size} advisory(ies)."
  end
end
