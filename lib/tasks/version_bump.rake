# frozen_string_literal: true

def dry_run?
  !!ENV["DRY_RUN"]
end

def test_mode?
  ENV["UNSAFE_SKIP_VERSION_BUMP_INTERACTIONS"] == "1"
end

class PlannedTag
  attr_reader :name, :message

  def initialize(name:, message:)
    @name = name
    @message = message
  end
end

class PlannedCommit
  attr_reader :version, :tags
  attr_accessor :ref

  def initialize(version:, tags: [], ref: nil)
    @version = version
    @tags = tags
    @ref = ref
  end
end

def read_version_rb
  File.read("lib/version.rb")
end

def parse_current_version
  version = read_version_rb[/STRING = "(.*)"/, 1]
  puts "Parsed current version: #{version}"
  version
end

def write_version(version)
  File.write("lib/version.rb", read_version_rb.sub(/STRING = ".*"/, "STRING = \"#{version}\""))
end

def git(*args, allow_failure: false, silent: false)
  puts "> git #{args.inspect}" unless silent
  stdout, stderr, status = Open3.capture3({ "LEFTHOOK" => "0" }, "git", *args)
  if !status.success? && !allow_failure
    raise "Command failed: git #{args.inspect}\n#{stdout.indent(2)}\n#{stderr.indent(2)}"
  end
  stdout
end

def ref_exists?(ref)
  git "rev-parse", "--verify", ref
  true
rescue StandardError
  false
end

def confirm(msg)
  loop do
    print "#{msg} (yes/no)..."
    break if test_mode?

    response = $stdin.gets.strip

    case response.downcase
    when "no"
      raise "Aborted"
    when "yes"
      break
    else
      puts "unknown response: #{response}"
    end
  end
end

def make_commits(commits:, branch:, base:)
  raise "You have other staged changes. Aborting." if !git("diff", "--cached").empty?

  git "branch", "-D", branch if ref_exists?(branch)
  git "checkout", "-b", branch

  commits.each do |commit|
    write_version(commit.version)
    git "add", "lib/version.rb"
    git "commit", "-m", "Bump version to v#{commit.version}"
    commit.ref = git("rev-parse", "HEAD").strip
  end

  git("push", "-f", "--set-upstream", "origin", branch)

  make_pr(
    base: base,
    branch: branch,
    title:
      "Version bump#{"s" if commits.length > 1} for #{base}: #{commits.map { |c| "v#{c.version}" }.join(", ")}",
  )
end

def make_pr(base:, branch:, title:)
  params = { expand: 1, title: title, body: <<~MD }
      > :warning: This PR should not be merged via the GitHub web interface
      > 
      > It should only be merged (via fast-forward) using the associated `bin/rake version_bump:*` task.
    MD

  if !test_mode?
    system(
      "open",
      "https://github.com/discourse/discourse/compare/#{base}...#{branch}?#{params.to_query}",
      exception: true,
    )
  end

  puts "Do not merge the PR via the GitHub web interface. Get it approved, then come back here to continue."
end

def fastforward(base:, branch:)
  if dry_run?
    puts "[DRY RUN] Skipping fastforward of #{base}"
    return
  end

  confirm "Ready to merge? This will fast-forward #{base} to #{branch}"
  begin
    git "push", "origin", "#{branch}:#{base}"
  rescue => e
    raise <<~MSG
      #{e.message}
      Error occured during fastforward. Maybe another commit was added to `#{base}` since the PR was created, or maybe the PR wasn't approved.
      Don't worry, this is not unusual. To update the branch and try again, rerun this script again. The existing PR and approval will be reused.
    MSG
  end
  puts "Merge successful"
end

def stage_tags(commits)
  puts "Staging tags locally..."
  commits.each do |commit|
    commit.tags.each { |tag| git "tag", "-f", "-a", tag.name, "-m", tag.message, commit.ref }
  end
end

def push_tags(commits)
  tag_names = commits.flat_map { |commit| commit.tags.map(&:name) }

  if dry_run?
    puts "[DRY RUN] Skipping pushing tags to origin (#{tag_names.join(", ")})"
    return
  end

  confirm "Ready to push tags #{tag_names.join(", ")} to origin?"
  tag_names.each { |tag_name| git "push", "-f", "origin", tag_name }
end

def with_clean_worktree(origin_branch)
  origin_url = git("remote", "get-url", "origin").strip

  if !test_mode? && !origin_url.include?("discourse/discourse")
    raise "Expected 'origin' remote to point to discourse/discourse (got #{origin_url})"
  end

  git "fetch", "origin", origin_branch
  path = "#{Rails.root}/tmp/version-bump-worktree-#{SecureRandom.hex}"
  begin
    FileUtils.mkdir_p(path)
    git "worktree", "add", path, "origin/#{origin_branch}"
    Dir.chdir(path) { yield } # rubocop:disable Discourse/NoChdir
  ensure
    git "worktree", "remove", "--force", path, silent: true, allow_failure: true
    FileUtils.rm_rf(path)
  end
end

desc "Stage commits for a beta version bump (e.g. beta1.dev -> beta1 -> beta2.dev). A PR will be created for approval, then the script will prompt to perform the release"
task "version_bump:beta" do
  branch = "version_bump/beta"
  base = "main"

  with_clean_worktree(base) do
    current_version = parse_current_version
    raise "Expected current version to end in -dev" if !current_version.end_with?("-dev")

    beta_release_version = current_version.sub("-dev", "")
    next_dev_version = current_version.sub(/beta(\d+)/) { "beta#{$1.to_i + 1}" }

    commits = [
      PlannedCommit.new(
        version: beta_release_version,
        tags: [
          PlannedTag.new(name: "beta", message: "latest beta release"),
          PlannedTag.new(name: "latest-release", message: "latest release"),
          PlannedTag.new(
            name: "v#{beta_release_version}",
            message: "version #{beta_release_version}",
          ),
        ],
      ),
      PlannedCommit.new(version: next_dev_version),
    ]

    make_commits(commits: commits, branch: branch, base: base)
    fastforward(base: base, branch: branch)
    stage_tags(commits)
    push_tags(commits)
  end

  puts "Done!"
end

desc "Stage commits for minor stable version bump (e.g. 3.1.1 -> 3.1.2). A PR will be created for approval, then the script will prompt to perform the release"
task "version_bump:minor_stable" do
  base = "stable"
  branch = "version_bump/stable"

  with_clean_worktree(base) do
    current_version = parse_current_version
    if current_version !~ /^(\d+)\.(\d+)\.(\d+)$/
      raise "Expected current stable version to be in the form X.Y.Z"
    end

    new_version = current_version.sub(/\.(\d+)\z/) { ".#{$1.to_i + 1}" }

    commits = [
      PlannedCommit.new(
        version: new_version,
        tags: [PlannedTag.new(name: "v#{new_version}", message: "version #{new_version}")],
      ),
    ]

    make_commits(commits: commits, branch: branch, base: base)
    fastforward(base: base, branch: branch)
    stage_tags(commits)
    push_tags(commits)
  end

  puts "Done!"
end

desc "Stage commits for a major version bump (e.g. 3.1.0.beta6-dev -> 3.1.0.beta6 -> 3.1.0 -> 3.2.0.beta1-dev). A PR will be created for approval, then the script will merge to `main`. Should be passed a version number for the next stable version (e.g. 3.2.0)"
task "version_bump:major_stable_prepare", [:next_major_version_number] do |t, args|
  unless args[:next_major_version_number] =~ /\A\d+\.\d+\.\d+\z/
    raise "Expected next_major_version number to be in the form X.Y.Z"
  end

  base = "main"
  branch = "version_bump/beta"

  with_clean_worktree(base) do
    current_version = parse_current_version

    # special case for moving away from the 'legacy' release system where we don't use the `-dev` suffix
    is_31_release = args[:next_major_version_number] == "3.2.0"

    if !current_version.end_with?("-dev") && !is_31_release
      raise "Expected current version to end in -dev"
    end

    beta_release_version = current_version.sub("-dev", "")
    stable_release_version = beta_release_version.sub(/\.beta\d+\z/, "")
    next_dev_version = args[:next_major_version_number] + ".beta1-dev"

    commits = []
    stable_commit = nil

    if is_31_release
      # The 3.1.0 beta series didn't use the -dev suffix, so we're jumping stright to
      # the next stable version, and need to tag it with beta/latest-release
      commits << stable_commit =
        PlannedCommit.new(
          version: stable_release_version,
          tags: [
            PlannedTag.new(name: "beta", message: "latest beta release"),
            PlannedTag.new(name: "latest-release", message: "latest release"),
          ],
        )
    else
      commits << PlannedCommit.new(
        version: beta_release_version,
        tags: [
          PlannedTag.new(name: "beta", message: "latest beta release"),
          PlannedTag.new(name: "latest-release", message: "latest release"),
          PlannedTag.new(
            name: "v#{beta_release_version}",
            message: "version #{beta_release_version}",
          ),
        ],
      )
      commits << stable_commit = PlannedCommit.new(version: stable_release_version)
    end

    commits << PlannedCommit.new(version: next_dev_version)

    make_commits(commits: commits, branch: branch, base: base)
    fastforward(base: base, branch: branch)
    stage_tags(commits)
    push_tags(commits)

    puts <<~MSG
      The #{base} branch is now ready for a stable release.
      Now run this command to merge the release into the stable branch:
        bin/rake "version_bump:major_stable_merge[#{stable_commit.ref}]"
    MSG
  end
end

desc "Stage the merge of a stable version bump into the stable branch. A PR will be created for approval, then the script will merge to `stable`. Should be passed the ref of the major version bump commit (output from the version_bump:major_stable_prepare rake task)"
task "version_bump:major_stable_merge", [:version_bump_ref] do |t, args|
  merge_ref = args[:version_bump_ref]
  unless merge_ref =~ /\A\w+\z/ && ref_exists?(merge_ref)
    raise "Unknown version_bump_ref: #{merge_ref.inspect}"
  end

  base = "stable"
  branch = "version_bump/stable"

  with_clean_worktree(base) do
    git "branch", "-D", branch if ref_exists?(branch)
    git "checkout", "-b", branch

    git "merge", "--no-commit", merge_ref, allow_failure: true

    out, status = Open3.capture2e "git diff --binary #{merge_ref} | patch -p1 -R"
    raise "Error applying diff\n#{out}}" unless status.success?

    git "add", "."

    merged_version = parse_current_version
    git "commit", "-m", "Merge v#{merged_version} into #{base}"
    ref = git("rev-parse", "HEAD").strip

    merge_commit =
      PlannedCommit.new(
        version: merged_version,
        ref: ref,
        tags: [PlannedTag.new(name: "v#{merged_version}", message: "version #{merged_version}")],
      )

    diff_to_base = git("diff", merge_ref).strip
    raise "There are diffs remaining to #{merge_ref}" unless diff_to_base.empty?

    git("push", "-f", "--set-upstream", "origin", branch)

    make_pr(base: base, branch: branch, title: "Merge v#{merged_version} into #{base}")
    fastforward(base: base, branch: branch)
    stage_tags([merge_commit])
    push_tags([merge_commit])
  end
end
