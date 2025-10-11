def dry_run?
  !!ENV["DRY_RUN"]
end

def test_mode?
  ENV["RUNNING_VERSION_BUMP_IN_RSPEC_TESTS"] == "1"
end

class PlannedTag
  attr_reader :name, :message

  def initialize(name:, message:)
    @name = name
    @message = message
  end
end

class PlannedCommit
  attr_reader :version, :tags, :ref

  def initialize(version:, tags: [])
    @version = version
    @tags = tags
  end

  def perform!
    write_version(@version)
    git "add", "lib/version.rb"
    git "commit", "-m", "Bump version to v#{@version}"
    @ref = git("rev-parse", "HEAD").strip
  end
end

def read_version_rb
  File.read("lib/version.rb")
end

def parse_current_version
  version = read_version_rb[/STRING = "(.*)"/, 1]
  raise "Unable to parse current version" if version.nil?
  puts "Parsed current version: #{version.inspect}"
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

  commits.each(&:perform!)

  git("push", "-f", "--set-upstream", "origin", branch)

  make_pr(
    base: base,
    branch: branch,
    title:
      "Version bump#{"s" if commits.length > 1} for #{base}: #{commits.map { |c| "v#{c.version}" }.join(", ")}",
  )
end

def make_pr(base:, branch:, title:, gh_cli: false)
  params = { expand: 1, title: title, body: <<~MD }
      > :warning: This PR should not be merged via the GitHub web interface
      >
      > It should only be merged (via fast-forward) using the associated `bin/rake version_bump:*` task.
    MD

  return if test_mode?

  if gh_cli
    system("gh pr create --base #{base} --head #{branch} --title #{title} --body #{params[:body]}")
  else
    open_command =
      case RbConfig::CONFIG["host_os"]
      when /darwin|mac os/
        "open"
      when /linux|solaris|bsd/
        "xdg-open"
      when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
        "start"
      else
        raise "Unsupported OS"
      end

    system(
      open_command,
      "https://github.com/discourse/discourse/compare/#{base}...#{branch}?#{params.to_query}",
      exception: true,
    )

    puts "Do not merge the PR via the GitHub web interface. Get it approved, then come back here to continue."
  end
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
  tag_names.each { |tag_name| git "push", "-f", "origin", "refs/tags/#{tag_name}" }
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
    puts "Cleaning up temporary worktree..."
    git "worktree", "remove", "--force", path, silent: true, allow_failure: true
    FileUtils.rm_rf(path)
  end
end

desc "Check a commit hash and create a release branch if it's a trigger"
task "release:maybe_cut_branch", [:check_ref] do |t, args|
  check_ref = args[:check_ref]

  with_clean_worktree("main") do
    git("checkout", "#{check_ref}")
    new_version = parse_current_version

    git("checkout", "#{check_ref}^1")
    previous_version = parse_current_version

    return "version has not changed" if new_version == previous_version

    raise "Unexpected previous version" if !previous_version.ends_with? "-latest"
    raise "Unexpected new version" if !new_version.ends_with? "-latest"
    if Gem::Version.new(new_version) < Gem::Version.new(previous_version)
      raise "New version is smaller than old version"
    end

    parts = previous_version.split(".")
    new_branch_name = "release/#{parts[0]}.#{parts[1]}"

    git("branch", new_branch_name)
    puts "Created new branch #{new_branch_name}"

    if dry_run?
      puts "[DRY RUN] Skipping pushing branch #{new_branch_name} to origin"
    else
      git("push", "--set-upstream", "origin", new_branch_name)
      puts "Pushed branch #{new_branch_name} to origin"
    end
  end

  puts "Done!"
end

desc "Maybe tag release"
task "release:maybe_tag_release", [:check_ref] do |t, args|
  check_ref = args[:check_ref]

  with_clean_worktree("main") do
    git "checkout", "#{check_ref}"
    # Find all branches (local and remote) containing this commit
    release_branches = git("branch", "-a", "--contains", check_ref, "release/*").lines.map(&:strip)
    if release_branches.empty?
      puts "Commit #{check_ref} is not on a release/* branch. Skipping"
      next
    end

    current_version = parse_current_version
    is_prerelease = current_version.include?("-")

    if is_prerelease
      puts "Current version #{current_version} is a prerelease. Skipping"
      next
    else
      tag_name = "v#{current_version}"
      if ref_exists?(tag_name)
        puts "Tag #{tag_name} already exists, skipping"
      else
        puts "Tagging release #{tag_name}"
        git "tag", "-a", tag_name, "-m", "version #{current_version}"
        if dry_run?
          puts "[DRY RUN] Skipping pushing tag to origin"
        else
          git "push", "origin", "refs/tags/#{tag_name}"
        end
      end
    end
  end

  puts "Done!"
end

desc "Prepare a version bump PR for `main`"
task "version_bump:prepare_next_version" do |t, args|
  pr_branch_name = "version-bump/main"

  branch = args[:branch]

  with_clean_worktree(branch) do
    git "branch", "-D", pr_branch_name if ref_exists?(branch)
    git "checkout", "-b", pr_branch_name

    current_version = parse_current_version

    target_version_number = "#{Time.now.strftime("%Y.%m")}.0-latest"

    if Gem::Version.new(target_version_number) <= Gem::Version.new(current_version)
      # We're going to try and keep versions aligned with months. But if not, this logic will kick in:
      puts "Target version #{current_version} is already >= #{target_version_number}. Incrementing instead."
      major, minor, patch_and_pre = current_version.split(".")
      minor = (minor.to_i + 1).to_s.rjust(2, "0")
      target_version_number = "#{major}.#{minor}.#{patch_and_pre}"
    end

    write_version(target_version_number)
    git "add", "lib/version.rb"
    git "commit",
        "-m",
        "Begin development of v#{target_version_number}\n\nMerging this will trigger the creation of a 'release/#{current_version.sub(".0-latest", "")}' branch on the preceding commit."
  end
end
