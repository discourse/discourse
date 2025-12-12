# frozen_string_literal: true

def run(*args)
  out, err, status = Open3.capture3(*args)
  raise "Command failed: #{args.inspect}\n#{out}\n#{err}" unless status.success?
  out
end

def fake_version_rb(version)
  File.read("#{Rails.root}/lib/version.rb").sub(/STRING = ".*"/, "STRING = \"#{version}\"")
end

RSpec.describe "tasks/version_bump" do
  let(:tmpdir) { Dir.mktmpdir }
  let(:origin_path) { "#{tmpdir}/origin-repo" }
  let(:local_path) { "#{tmpdir}/local-repo" }

  before do
    ENV["RUNNING_VERSION_BUMP_IN_RSPEC_TESTS"] = "1"

    Rake::Task.clear
    Discourse::Application.load_tasks

    FileUtils.mkdir_p origin_path

    Dir.chdir(origin_path) do
      FileUtils.mkdir_p "lib"
      FileUtils.mkdir_p "tmp"

      File.write(".gitignore", "tmp\n")
      File.write("lib/version.rb", fake_version_rb("3.2.0.beta1-latest"))

      run "git", "init"
      run "git", "checkout", "-b", "main"
      run "git", "add", "."
      run "git", "-c", "commit.gpgsign=false", "commit", "-m", "Initial commit"

      run "git", "checkout", "-b", "stable"
      File.write("#{origin_path}/lib/version.rb", fake_version_rb("3.1.2"))
      run "git", "add", "."
      run "git", "-c", "commit.gpgsign=false", "commit", "-m", "Previous stable version bump"

      run "git", "checkout", "main"
      run "git", "config", "receive.denyCurrentBranch", "ignore"
    end

    run "git", "clone", "-b", "main", origin_path, local_path
  end

  after do
    FileUtils.remove_entry(tmpdir)
    ENV.delete("RUNNING_VERSION_BUMP_IN_RSPEC_TESTS")
  end

  it "can stage a PR of multiple security fixes using version_bump:stage_security_fixes" do
    Dir.chdir(origin_path) do
      run "git", "checkout", "-b", "security-fix-one"

      File.write("firstfile.txt", "contents")
      run "git", "add", "firstfile.txt"
      run "git", "-c", "commit.gpgsign=false", "commit", "-m", "security fix one, commit one"
      File.write("secondfile.txt", "contents")
      run "git", "add", "secondfile.txt"
      run "git", "-c", "commit.gpgsign=false", "commit", "-m", "security fix one, commit two"

      run "git", "checkout", "main"
      run "git", "checkout", "-b", "security-fix-two"
      File.write("somefile.txt", "contents")
      run "git", "add", "somefile.txt"
      run "git", "-c", "commit.gpgsign=false", "commit", "-m", "security fix two"
    end

    Dir.chdir(local_path) do
      output =
        capture_stdout do
          ENV["SECURITY_FIX_REFS"] = "origin/security-fix-one,origin/security-fix-two"
          invoke_rake_task("version_bump:stage_security_fixes", "main")
        ensure
          ENV.delete("SECURITY_FIX_REFS")
        end
    end

    Dir.chdir(origin_path) do
      # Check each fix has been added as a single commit, with the message matching the first commit on the branch
      expect(run("git", "log", "--pretty=%s", "main").lines.map(&:strip)).to eq(
        [
          "security fix two",
          "security fix one, commit two",
          "security fix one, commit one",
          "Initial commit",
        ],
      )

      # Check all the files from both fixes are present
      expect(run("git", "show", "main:somefile.txt")).to eq("contents")
      expect(run("git", "show", "main:firstfile.txt")).to eq("contents")
      expect(run("git", "show", "main:secondfile.txt")).to eq("contents")
    end
  end
end
