# frozen_string_literal: true

RSpec.describe GitUtils do
  let(:temp_dir) { Dir.mktmpdir }

  before { GitUtils.instance_variable_set(:@filesystem_overrides, nil) }

  after { FileUtils.remove_entry(temp_dir) }

  def run(command)
    system(command, exception: true)
  end

  def within_temp_git_repo(&block)
    Dir.chdir(temp_dir) do
      run("git init --quiet")
      run("git config user.email 'test@example.com'")
      run("git config user.name 'Test User'")
      run("git config commit.gpgsign false")
      run("git checkout --quiet -b main")
      yield
    end
  end

  def create_commit(filename = "test.txt")
    File.write(filename, "content")
    run("git add #{filename}")
    run("git commit --quiet -m 'Commit #{filename}'")
  end

  it "returns git version, branch, full_version, and last_commit_date" do
    within_temp_git_repo do
      create_commit
      run("git checkout --quiet -b feature-branch")
      run("git tag -a v1.0.0 -m 'Version 1.0.0'")

      expect(GitUtils.git_version).to eq(`git rev-parse HEAD`.strip)
      expect(GitUtils.git_branch).to eq("feature-branch")
      expect(GitUtils.full_version).to start_with("v1.0.0")
      expect(GitUtils.last_commit_date).to be_within(60).of(DateTime.now)
    end
  end

  it "returns fallback values when missing data" do
    within_temp_git_repo do
      create_commit
      run("git checkout --quiet --detach HEAD")
      expect(GitUtils.git_branch).to eq("unknown")
    end
  end

  it "falls back to user.discourse-version when in detached HEAD" do
    within_temp_git_repo do
      create_commit
      run("git config user.discourse-version 'v3.2.0'")
      run("git checkout --quiet --detach HEAD")

      expect(GitUtils.git_branch).to eq("v3.2.0")
    end
  end

  describe ".has_commit?" do
    it "validates commit existence and format" do
      within_temp_git_repo do
        create_commit
        first_sha = `git rev-parse HEAD`.strip
        create_commit("test2.txt")

        expect(GitUtils.has_commit?(first_sha)).to eq(true)
        expect(GitUtils.has_commit?("a" * 40)).to eq(false)
        expect(GitUtils.has_commit?("invalid")).to eq(false)
      end
    end
  end

  describe ".filesystem_overrides" do
    it "reads overrides from JSON file and applies them to git methods" do
      FileUtils.mkdir_p(File.join(temp_dir, "config"))
      File.write(
        File.join(temp_dir, "config", "git-utils-overrides.json"),
        {
          "git_version" => "override-sha",
          "git_branch" => "override-branch",
          "full_version" => "override-full",
        }.to_json,
      )
      GitUtils.stubs(:rails_root).returns(Pathname.new(temp_dir))

      within_temp_git_repo do
        create_commit
        expect(GitUtils.git_version).to eq("override-sha")
        expect(GitUtils.git_branch).to eq("override-branch")
        expect(GitUtils.full_version).to eq("override-full")
      end
    end

    it "returns regular info when file does not exist" do
      GitUtils.stubs(:rails_root).returns(Pathname.new(temp_dir))
      within_temp_git_repo do
        create_commit
        expect(GitUtils.git_version).to eq(`git rev-parse HEAD`.strip)
        expect(GitUtils.git_branch).to eq("main")
        expect(GitUtils.full_version).to eq("unknown")
      end
    end
  end

  it "calculates rails root correctly" do
    expected = Rails.root
    Rails.stubs(:root).raises "Rails.root might not be available during GitUtils initialization"
    expect(GitUtils.send(:rails_root)).to eq(expected)
  ensure
    # This will get unstubbed automatically by rails_helper, but we gotta do it
    # even earlier, since some other test cleanup code calls Rails.root
    Rails.unstub(:root)
  end
end
