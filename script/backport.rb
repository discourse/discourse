# frozen_string_literal: true

require "json"
require "open3"

RunResult = Struct.new(:success, :stdout, :stderr, keyword_init: true)

def run(*cmd, allow_failure: false)
  puts "Running: #{cmd.join(" ")}"
  stdout, stderr, status = Open3.capture3(*cmd)
  puts stdout unless stdout.empty?
  puts stderr unless stderr.empty?
  raise "Command failed: #{cmd.join(" ")}\n#{stderr}" unless status.success? || allow_failure
  RunResult.new(success: status.success?, stdout: stdout.strip, stderr: stderr.strip)
end

def gh(*args, allow_failure: false)
  run("gh", *args, allow_failure: allow_failure)
end

pr_number = ENV.fetch("PR_NUMBER")

# Get PR details (title, body, base branch)
pr = JSON.parse(gh("pr", "view", pr_number, "--json", "title,body,baseRefName").stdout)

pr_title = pr["title"]
pr_body = pr["body"] || ""
base_branch = pr["baseRefName"]

puts "PR ##{pr_number}: #{pr_title}"
puts "Base branch: #{base_branch}"

# Fetch the PR head using GitHub's magic ref (works for forks too)
pr_ref = "refs/pull/#{pr_number}/head"
run("git", "fetch", "origin", "#{pr_ref}:pr-head")

# Fetch the base branch
run("git", "fetch", "origin", base_branch)

# Find merge base between PR head and base branch
merge_base = run("git", "merge-base", "pr-head", "origin/#{base_branch}").stdout
pr_head = run("git", "rev-parse", "pr-head").stdout
puts "Merge base: #{merge_base}"

# Read versions.json from main branch to find backport targets
versions = JSON.parse(run("git", "show", "origin/main:versions.json").stdout)

# Find versions that are both supported and released
backport_versions =
  versions
    .select { |version, info| info["supported"] == true && info["released"] == true }
    .keys
    .sort
    .reverse

puts "Will backport to versions: #{backport_versions.join(", ")}"

if backport_versions.empty?
  gh(
    "pr",
    "comment",
    pr_number,
    "--body",
    "No supported and released versions found to backport to.",
  )
  exit 0
end

results = []

backport_versions.each do |version|
  release_branch = "release/#{version}"
  backport_branch = "backport/#{version}/#{pr_number}"

  puts "\n--- Backporting to #{release_branch} ---"

  # Check if release branch exists
  if !run("git", "ls-remote", "--heads", "origin", release_branch).stdout.include?(release_branch)
    puts "Release branch #{release_branch} does not exist, skipping"
    results << { version: version, success: false, error: "Release branch does not exist" }
    next
  end

  # Fetch the release branch
  run("git", "fetch", "origin", release_branch)

  # Create backport branch from release branch
  run("git", "checkout", "-B", backport_branch, "origin/#{release_branch}")

  # Cherry-pick the commits
  cherry_pick_range = "#{merge_base}..#{pr_head}"
  puts "Cherry-picking #{cherry_pick_range}..."
  result = run("git", "cherry-pick", cherry_pick_range, allow_failure: true)

  unless result.success
    puts "Failed to backport to #{version}:\n#{result.stderr}"
    results << {
      version: version,
      success: false,
      error: result.stderr,
      release_branch: release_branch,
      backport_branch: backport_branch,
      cherry_pick_range: cherry_pick_range,
    }
    run("git", "cherry-pick", "--abort", allow_failure: true)
    run("git", "checkout", "main", allow_failure: true)
    next
  end

  # Push the backport branch
  run("git", "push", "-f", "origin", backport_branch)

  # Create or update PR
  backport_title = "#{pr_title} [backport #{version}]"
  backport_body = <<~BODY
    Backport of ##{pr_number} to #{release_branch}.

    ---

    #{pr_body}
  BODY

  # Try to create the PR
  created =
    gh(
      "pr",
      "create",
      "--base",
      release_branch,
      "--head",
      backport_branch,
      "--title",
      backport_title,
      "--body",
      backport_body,
      allow_failure: true,
    ).success

  if created
    # Get the PR URL for the newly created PR
    pr_url = gh("pr", "view", backport_branch, "--json", "url", "-q", ".url").stdout.strip
    puts "Created PR: #{pr_url}"
  else
    # PR already exists, update it
    puts "PR already exists, updating..."
    gh("pr", "edit", backport_branch, "--title", backport_title, "--body", backport_body)
    pr_url = gh("pr", "view", backport_branch, "--json", "url", "-q", ".url").stdout.strip
    puts "Updated PR: #{pr_url}"
  end

  results << { version: version, success: true, pr_url: pr_url }

  # Return to main branch for next iteration
  run("git", "checkout", "main", allow_failure: true)
end

# Post summary comment
successful = results.select { |r| r[:success] }
failed = results.reject { |r| r[:success] }

comment_lines = ["## Backport Results\n"]

if successful.any?
  comment_lines << "### Successful backports"
  successful.each { |r| comment_lines << "- #{r[:version]}: #{r[:pr_url]}" }
  comment_lines << ""
end

if failed.any?
  comment_lines << "### Failed backports"
  failed.each do |r|
    if r[:cherry_pick_range]
      comment_lines << <<~MSG
        #### #{r[:version]}
        ```
        #{r[:error]}
        ```

        To resolve manually:
        ```bash
        git checkout -B #{r[:backport_branch]} origin/#{r[:release_branch]}
        git cherry-pick #{r[:cherry_pick_range]}
        ```
      MSG
    else
      comment_lines << "- **#{r[:version]}**: #{r[:error]}"
    end
  end
end

comment_lines << "No backports were attempted." if successful.empty? && failed.empty?

gh("pr", "comment", pr_number, "--body", comment_lines.join("\n"))
puts "\nBackport complete!"
