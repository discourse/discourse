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
    ENV["RUNNING_RELEASE_IN_RSPEC_TESTS"] = "1"

    Rake::Task.tasks.each { |t| t.reenable }
    FileUtils.mkdir_p origin_path

    Dir.chdir(origin_path) do
      FileUtils.mkdir_p "lib"
      FileUtils.mkdir_p "tmp"

      File.write(".gitignore", "tmp\n")
      File.write("lib/version.rb", fake_version_rb("3.2.0.beta1-latest"))

      run "git", "init"
      run "git", "checkout", "-b", "main"
      run "git", "add", "."
      run "git", "commit", "-m", "Initial commit"

      run "git", "checkout", "-b", "stable"
      File.write("#{origin_path}/lib/version.rb", fake_version_rb("3.1.2"))
      run "git", "add", "."
      run "git", "commit", "-m", "Previous stable version bump"

      run "git", "checkout", "main"
      run "git", "config", "receive.denyCurrentBranch", "ignore"
    end

    run "git", "clone", "-b", "main", origin_path, local_path
  end

  after do
    FileUtils.remove_entry(tmpdir)
    ENV.delete("RUNNING_VERSION_BUMP_IN_RSPEC_TESTS")
  end

  describe "release:maybe_tag_release" do
    it "does not tag if commit is not on a release/* branch" do
      Dir.chdir(local_path) do
        run "git", "switch", "-c", "some-other-branch"
        File.write("lib/version.rb", fake_version_rb("2025.06.0"))
        run "git", "add", "."
        run "git", "commit", "-m", "release 2025.06.0"
        commit_hash = run("git", "rev-parse", "HEAD").strip
        # Not on a release/* branch, should not tag
        capture_stdout { invoke_rake_task("release:maybe_tag_release", commit_hash) }
        # Should not tag, so v2025.06.0 should not exist
        expect(run("git", "tag").lines.map(&:strip)).not_to include("v2025.06.0")
      end
    end

    it "tags a release if tag does not exist" do
      Dir.chdir(local_path) do
        File.write("lib/version.rb", fake_version_rb("2025.03.0"))
        run "git", "add", "."
        run "git", "commit", "-m", "release 2025.03.0"
        commit_hash = run("git", "rev-parse", "HEAD").strip
        run "git", "branch", "release/2025.03"
        output = capture_stdout { invoke_rake_task("release:maybe_tag_release", commit_hash) }
        expect(output).to include("Tagging release v2025.03.0")
        expect(run("git", "tag").lines.map(&:strip)).to include("v2025.03.0")
      end
    end

    it "tags first commit of a pre-release cycle" do
      Dir.chdir(local_path) do
        File.write("lib/version.rb", fake_version_rb("2025.04.0-latest"))
        run "git", "add", "."
        run "git", "commit", "-m", "bump to 2025.04.0-latest"
        commit_hash = run("git", "rev-parse", "HEAD").strip
        output = capture_stdout { invoke_rake_task("release:maybe_tag_release", commit_hash) }
        expect(output).to include("Tagging release v2025.04.0-latest")
        expect(run("git", "tag").lines.map(&:strip)).to include("v2025.04.0-latest")
      end
    end

    it "skips tagging if tag already exists" do
      Dir.chdir(local_path) do
        File.write("lib/version.rb", fake_version_rb("2025.05.0"))
        run "git", "add", "."
        run "git", "commit", "-m", "release 2025.05.0"
        commit_hash = run("git", "rev-parse", "HEAD").strip
        run "git", "branch", "release/2025.05"
        # Create tag manually
        run "git", "tag", "-a", "v2025.05.0", "-m", "version 2025.05.0"
        output = capture_stdout { invoke_rake_task("release:maybe_tag_release", commit_hash) }
        expect(output).to include("Tag v2025.05.0 already exists, skipping")
      end
    end
  end

  it "can create a new release branch" do
    latest_hash, previous_hash = nil

    Dir.chdir(local_path) do
      File.write("lib/version.rb", fake_version_rb("2025.01.0-latest"))
      run "git", "add", "."
      run "git", "commit", "-m", "developing 2025.01"

      previous_hash = run("git", "rev-parse", "HEAD").strip

      File.write("lib/version.rb", fake_version_rb("2025.02.0-latest"))
      run "git", "add", "."
      run "git", "commit", "-m", "begin development of 2025.02-latest"

      latest_hash = run("git", "rev-parse", "HEAD").strip

      output = capture_stdout { invoke_rake_task("release:maybe_cut_branch", latest_hash) }
      expect(output).to include("Created new branch")
    end

    Dir.chdir(origin_path) do
      run "git", "checkout", "release/2025.01"
      branch_tip = run("git", "rev-parse", "HEAD").strip
      expect(branch_tip).to eq(previous_hash)
    end
  end

  describe "release:prepare_next_version" do
    it "bumps version to current month format when current version is older" do
      Dir.chdir(local_path) do
        File.write("lib/version.rb", fake_version_rb("2024.01.0-latest"))
        run "git", "add", "."
        run "git", "commit", "-m", "old version"
        run "git", "push", "origin", "main"

        freeze_time Time.utc(2025, 9, 15) do
          capture_stdout { invoke_rake_task("release:prepare_next_version") }
        end
      end

      Dir.chdir(origin_path) do
        run "git", "reset", "--hard"
        run "git", "checkout", "version-bump/main"
        version_rb_content = File.read("lib/version.rb")
        expect(version_rb_content).to include('STRING = "2025.09.0-latest"')
      end
    end

    it "increments minor version when current version is already >= target month version" do
      Dir.chdir(local_path) do
        File.write("lib/version.rb", fake_version_rb("2025.10.0-latest"))
        run "git", "add", "."
        run "git", "commit", "-m", "current month version"
        run "git", "push", "origin", "main"

        freeze_time Time.utc(2025, 10, 15) do
          output = capture_stdout { invoke_rake_task("release:prepare_next_version") }
          expect(output).to include("is already >= 2025.10.0-latest. Incrementing instead.")
        end
      end

      Dir.chdir(origin_path) do
        run "git", "reset", "--hard"
        run "git", "checkout", "version-bump/main"
        version_rb_content = File.read("lib/version.rb")
        expect(version_rb_content).to include('STRING = "2025.11.0-latest"')
      end
    end

    it "creates version-bump/main branch with proper commit message" do
      Dir.chdir(local_path) do
        File.write("lib/version.rb", fake_version_rb("2025.05.0-latest"))
        run "git", "add", "."
        run "git", "commit", "-m", "previous version"
        run "git", "push", "origin", "main"

        freeze_time Time.utc(2025, 10, 15) do
          capture_stdout { invoke_rake_task("release:prepare_next_version") }
        end
      end

      Dir.chdir(origin_path) do
        run "git", "reset", "--hard"
        run "git", "checkout", "version-bump/main"
        current_branch = run("git", "branch", "--show-current").strip
        expect(current_branch).to eq("version-bump/main")

        commit_message = run("git", "log", "-1", "--pretty=%B").strip
        expect(commit_message).to include("Begin development of v2025.10.0-latest")
        expect(commit_message).to include(
          "Merging this will trigger the creation of a `release/2025.05` branch on the preceding commit.",
        )
      end
    end
  end
end
