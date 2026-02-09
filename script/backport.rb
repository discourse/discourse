# frozen_string_literal: true

require "json"
require "open3"

def run(*cmd, allow_failure: false)
  puts "Running: #{cmd.join(" ")}"
  stdout, stderr, status = Open3.capture3(*cmd)
  puts stdout unless stdout.empty?
  puts stderr unless stderr.empty?
  raise "Command failed: #{cmd.join(" ")}\n#{stderr}" unless status.success? || allow_failure
  [stdout.strip, status.success?]
end

def gh(*args, allow_failure: false)
  run("gh", *args, allow_failure: allow_failure)
end

pr_number = ENV.fetch("PR_NUMBER")

# Get PR details (title, body, base branch)
pr_json, = gh("pr", "view", pr_number, "--json", "title,body,baseRefName")
pr = JSON.parse(pr_json)

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
merge_base, = run("git", "merge-base", "pr-head", "origin/#{base_branch}")
puts "Merge base: #{merge_base}"

# Get commits from merge base to PR head (in chronological order)
commits_output, = run("git", "rev-list", "--reverse", "#{merge_base}..pr-head")
commits_to_pick = commits_output.split("\n").reject(&:empty?)

if commits_to_pick.empty?
  puts "No commits to backport"
  gh("pr", "comment", pr_number, "--body", "No commits found to backport.")
  exit 0
end

puts "Found #{commits_to_pick.length} commit(s) to cherry-pick:"
commits_to_pick.each do |sha|
  subject, = run("git", "log", "-1", "--pretty=%s", sha)
  puts "  - #{sha[0..7]}: #{subject}"
end

# Read versions.json from main branch to find backport targets
versions_content, = run("git", "show", "origin/main:versions.json")
versions = JSON.parse(versions_content)

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
  branch_exists, = run("git", "ls-remote", "--heads", "origin", release_branch)
  if !branch_exists.include?(release_branch)
    puts "Release branch #{release_branch} does not exist, skipping"
    results << { version: version, success: false, error: "Release branch does not exist" }
    next
  end

  # Fetch the release branch
  run("git", "fetch", "origin", release_branch)

  # Create backport branch from release branch
  run("git", "checkout", "-B", backport_branch, "origin/#{release_branch}")

  # Cherry-pick the commits
  cherry_pick_success = true
  error_message = nil

  commits_to_pick.each do |sha|
    puts "Cherry-picking #{sha}..."
    _, success = run("git", "cherry-pick", sha, allow_failure: true)
    unless success
      cherry_pick_success = false
      # Get the conflict details
      status_output, = run("git", "status", "--short", allow_failure: true)
      error_message = "Cherry-pick of #{sha} failed with conflicts:\n```\n#{status_output}\n```"
      run("git", "cherry-pick", "--abort", allow_failure: true)
      break
    end
  end

  if cherry_pick_success
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
    _, created =
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
      )

    if created
      # Get the PR URL for the newly created PR
      pr_url_output, = gh("pr", "view", backport_branch, "--json", "url", "-q", ".url")
      pr_url = pr_url_output.strip
      puts "Created PR: #{pr_url}"
    else
      # PR already exists, update it
      puts "PR already exists, updating..."
      gh("pr", "edit", backport_branch, "--title", backport_title, "--body", backport_body)
      pr_url_output, = gh("pr", "view", backport_branch, "--json", "url", "-q", ".url")
      pr_url = pr_url_output.strip
      puts "Updated PR: #{pr_url}"
    end

    results << { version: version, success: true, pr_url: pr_url }
  else
    puts "Failed to backport to #{version}: #{error_message}"
    results << { version: version, success: false, error: error_message }
  end

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
  failed.each { |r| comment_lines << "- **#{r[:version]}**: #{r[:error]}" }
end

comment_lines << "No backports were attempted." if successful.empty? && failed.empty?

gh("pr", "comment", pr_number, "--body", comment_lines.join("\n"))
puts "\nBackport complete!"
