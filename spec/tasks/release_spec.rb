# frozen_string_literal: true

RSpec.describe "tasks/version_bump" do
  let(:tmpdir) { Dir.mktmpdir }
  let(:origin_path) { "#{tmpdir}/origin-repo" }
  let(:local_path) { "#{tmpdir}/local-repo" }
  let(:git_tags) { git("tag").lines.map(&:strip) }

  def git(*args)
    out, err, status = Open3.capture3("git", *args)
    raise "Command failed: git #{args.inspect}\n#{out}\n#{err}" unless status.success?
    out
  end

  def fake_version_rb(version)
    File.read("#{Rails.root}/lib/version.rb").sub(/STRING = ".*"/, "STRING = \"#{version}\"")
  end

  def commit_version(version)
    File.write("lib/version.rb", fake_version_rb(version))
    git "add", "."
    git "commit", "-m", "version #{version}"
    git("rev-parse", "HEAD").strip
  end

  def update_versions_json(overrides)
    Dir.chdir(origin_path) do
      git "checkout", "main"
      current = JSON.parse(File.read("versions.json"))
      File.write("versions.json", JSON.pretty_generate(current.merge(overrides)))
      git "add", "versions.json"
      git "commit", "-m", "Update versions.json"
    end
  end

  before do
    ENV["RUNNING_RELEASE_IN_RSPEC_TESTS"] = "1"

    Rake::Task.tasks.each { |t| t.reenable }
    FileUtils.mkdir_p origin_path

    Dir.chdir(origin_path) do
      FileUtils.mkdir_p "lib"
      FileUtils.mkdir_p "tmp"

      File.write(".gitignore", "tmp\n")
      File.write("lib/version.rb", fake_version_rb("2025.12.0-latest"))
      versions =
        (1..12).each_with_object({}) do |month, hash|
          hash["2025.#{month}"] = { "released" => month <= 6, "esr" => [1, 7].include?(month) }
        end
      File.write("versions.json", JSON.pretty_generate(versions))

      git "init"
      git "checkout", "-b", "main"
      git "add", "."
      git "commit", "-m", "Initial commit"

      git "checkout", "-b", "stable"
      File.write("#{origin_path}/lib/version.rb", fake_version_rb("3.1.2"))
      git "add", "."
      git "commit", "-m", "Previous stable version bump"

      git "checkout", "main"
      git "config", "receive.denyCurrentBranch", "ignore"
    end

    git "clone", "-b", "main", origin_path, local_path
  end

  after do
    FileUtils.remove_entry(tmpdir)
    ENV.delete("RUNNING_RELEASE_IN_RSPEC_TESTS")
  end

  describe "release:maybe_tag_release" do
    subject(:run_task) do
      capture_stdout { invoke_rake_task("release:maybe_tag_release", commit_hash) }
    end

    let(:commit_hash) { commit_version(version) }

    context "when commit is not on a release branch" do
      let(:version) { "2025.6.0" }

      it "does not create a tag" do
        Dir.chdir(local_path) do
          git "switch", "-c", "some-other-branch"

          expect { run_task }.not_to change { git_tags }
        end
      end
    end

    context "when tag does not exist" do
      let(:version) { "2025.3.0" }
      let!(:commit_hash) { Dir.chdir(local_path) { commit_version(version) } }

      it "creates the tag" do
        Dir.chdir(local_path) do
          git "branch", "release/2025.3"

          expect(run_task).to include("Tagging release v2025.3.0")
          expect(git_tags).to include("v2025.3.0")
        end
      end
    end

    context "when version is a pre-release" do
      let(:version) { "2025.4.0-latest" }

      it "tags the pre-release version" do
        Dir.chdir(local_path) do
          expect(run_task).to include("Tagging release v2025.4.0-latest")
          expect(git_tags).to include("v2025.4.0-latest")
        end
      end
    end

    context "when version is a security patchlevel" do
      let(:version) { "2025.4.0-latest.1" }

      it "tags the patchlevel version" do
        Dir.chdir(local_path) do
          expect(run_task).to include("Tagging release v2025.4.0-latest.1")
          expect(git_tags).to include("v2025.4.0-latest.1")
        end
      end
    end

    context "when tag already exists" do
      let(:version) { "2025.5.0" }
      let!(:commit_hash) { Dir.chdir(local_path) { commit_version(version) } }

      it "skips tagging" do
        Dir.chdir(local_path) do
          git "branch", "release/2025.5"
          git "tag", "-a", "v2025.5.0", "-m", "version 2025.5.0"

          expect { run_task }.not_to change { git_tags }
        end
      end
    end
  end

  describe "release:update_release_tags" do
    subject(:run_task) do
      capture_stdout { invoke_rake_task("release:update_release_tags", commit_hash) }
    end

    let(:commit_hash) { commit_version(version) }

    context "when version is newer than latest release" do
      let(:version) { "2025.6.0" }

      it "creates release alias tags" do
        Dir.chdir(local_path) do
          run_task
          expect(git_tags).to contain_exactly(*ReleaseUtils::RELEASE_TAGS)
        end
      end
    end

    context "when version is older than latest release" do
      let(:version) { "2025.1.0" }

      it "skips release tags" do
        Dir.chdir(local_path) do
          expect(run_task).to include("older than latest release")
          expect(git_tags).not_to include(*ReleaseUtils::RELEASE_TAGS)
        end
      end
    end

    context "when version is a non-ESR release" do
      let(:version) { "2025.6.0" }

      it "does not create ESR tags" do
        Dir.chdir(local_path) do
          run_task
          expect(git_tags).not_to include(*ReleaseUtils::ESR_TAGS)
        end
      end
    end

    context "when version is in the latest released ESR series" do
      let(:version) { "2025.7.1" }

      before { update_versions_json({ "2025.7" => { "released" => true, "esr" => true } }) }

      it "creates both release and ESR alias tags" do
        Dir.chdir(local_path) do
          run_task
          expect(git_tags).to include(*ReleaseUtils::RELEASE_TAGS, *ReleaseUtils::ESR_TAGS)
        end
      end
    end

    context "when version is newer than the latest ESR but not an ESR itself" do
      let(:version) { "2025.8.0" }

      before do
        update_versions_json(
          {
            "2025.7" => {
              "released" => true,
              "esr" => true,
            },
            "2025.8" => {
              "released" => true,
              "esr" => false,
            },
          },
        )
      end

      it "creates release tags but not ESR tags" do
        Dir.chdir(local_path) do
          run_task
          expect(git_tags).to contain_exactly(*ReleaseUtils::RELEASE_TAGS)
        end
      end
    end
  end

  describe "release:maybe_cut_branch" do
    subject(:run_task) do
      capture_stdout { invoke_rake_task("release:maybe_cut_branch", latest_hash) }
    end

    context "when development cycle changes" do
      let!(:previous_hash) { Dir.chdir(local_path) { commit_version(previous_version) } }
      let!(:latest_hash) { Dir.chdir(local_path) { commit_version(current_version) } }

      def branch_tip(branch)
        Dir.chdir(origin_path) do
          git "checkout", branch
          git("rev-parse", "HEAD").strip
        end
      end

      context "when going from one minor to another" do
        let(:previous_version) { "2025.1.0-latest" }
        let(:current_version) { "2025.2.0-latest" }

        it "creates a release branch at the previous commit" do
          Dir.chdir(local_path) { run_task }

          expect(branch_tip("release/2025.1")).to eq(previous_hash)
        end
      end

      context "when going from a patchlevel to a new minor" do
        let(:previous_version) { "2025.11.0-latest.2" }
        let(:current_version) { "2025.12.0-latest" }

        it "creates a release branch at the previous commit" do
          Dir.chdir(local_path) { run_task }

          expect(branch_tip("release/2025.11")).to eq(previous_hash)
        end
      end
    end

    context "when development cycle stays the same" do
      def origin_branches
        Dir.chdir(origin_path) { git("branch").lines.map(&:strip) }
      end

      context "when bumping from latest to latest.1" do
        let!(:latest_hash) { Dir.chdir(local_path) { commit_version("2025.12.0-latest.1") } }

        it "does not create a branch" do
          Dir.chdir(local_path) { expect { run_task }.not_to change { origin_branches } }
        end
      end

      context "when bumping from latest.1 to latest.2" do
        let!(:intermediate_hash) { Dir.chdir(local_path) { commit_version("2025.12.0-latest.1") } }
        let!(:latest_hash) { Dir.chdir(local_path) { commit_version("2025.12.0-latest.2") } }

        it "does not create a branch" do
          Dir.chdir(local_path) { expect { run_task }.not_to change { origin_branches } }
        end
      end
    end
  end

  describe "release:prepare_next_version" do
    subject(:run_task) do
      Dir.chdir(local_path) do
        freeze_time(frozen_time) do
          capture_stdout { invoke_rake_task("release:prepare_next_version") }
        end
      end
    end

    let(:bumped_version) do
      on_version_bump_branch { File.read("lib/version.rb")[/STRING = "(.*)"/, 1] }
    end

    def on_version_bump_branch
      Dir.chdir(origin_path) do
        git "reset", "--hard"
        git "checkout", "version-bump/main"
        yield
      end
    end

    context "with a custom version on main" do
      before do
        Dir.chdir(local_path) do
          commit_version(initial_version)
          git "push", "origin", "main"
        end
      end

      context "when current version is older than target month" do
        let(:frozen_time) { "2025-09-15" }
        let(:initial_version) { "2024.1.0-latest" }

        it "bumps to the current month" do
          run_task
          expect(bumped_version).to eq("2025.9.0-latest")
        end
      end

      context "when current version matches target month" do
        let(:frozen_time) { "2025-10-15" }
        let(:initial_version) { "2025.10.0-latest" }

        it "increments to next month" do
          run_task
          expect(bumped_version).to eq("2025.11.0-latest")
        end
      end

      context "when current version has a security patchlevel" do
        let(:frozen_time) { "2025-10-15" }
        let(:initial_version) { "2025.10.0-latest.2" }

        it "increments to next month and drops patchlevel" do
          run_task
          expect(bumped_version).to eq("2025.11.0-latest")
        end
      end

      context "when PR creation succeeds" do
        let(:frozen_time) { "2025-10-15" }
        let(:initial_version) { "2025.5.0-latest" }
        let(:commit_message) { on_version_bump_branch { git("log", "-1", "--pretty=%B").strip } }

        before do
          allow(ReleaseUtils).to receive(:gh).with("pr", "create", any_args).and_return(true)
          run_task
        end

        it "includes the version bump description" do
          expect(commit_message).to include("Begin development of v2025.10.0-latest")
          expect(commit_message).to include(
            "Merging this will trigger the creation of a `release/2025.5` branch on the preceding commit.",
          )
        end

        it "creates a PR" do
          commit_message

          expect(ReleaseUtils).to have_received(:gh).with(
            "pr",
            "create",
            "--base",
            "main",
            "--head",
            "version-bump/main",
            "--title",
            "DEV: Begin development of v2025.10.0-latest",
            "--body",
            a_string_including(
              "Merging this will trigger the creation of a `release/2025.5` branch",
            ),
            "--label",
            ReleaseUtils::PR_LABEL,
          )
        end
      end

      context "when PR creation fails" do
        let(:frozen_time) { "2025-10-15" }
        let(:initial_version) { "2025.5.0-latest" }

        before do
          allow(ReleaseUtils).to receive(:gh).with("pr", "create", any_args).and_return(false)
          allow(ReleaseUtils).to receive(:gh).with("pr", "edit", any_args).and_return(true)
        end

        it "falls back to editing the PR" do
          run_task

          expect(ReleaseUtils).to have_received(:gh).with(
            "pr",
            "edit",
            "version-bump/main",
            "--title",
            "DEV: Begin development of v2025.10.0-latest",
            "--body",
            a_string_including(
              "Merging this will trigger the creation of a `release/2025.5` branch",
            ),
            "--add-label",
            ReleaseUtils::PR_LABEL,
          )
        end
      end
    end

    context "when incrementing past December" do
      let(:frozen_time) { "2025-12-15" }

      it "rolls over to next year" do
        run_task
        expect(bumped_version).to eq("2026.1.0-latest")
      end
    end

    context "when updating versions.json" do
      let(:frozen_time) { "2025-12-28" }
      let(:versions_json) { on_version_bump_branch { JSON.parse(File.read("versions.json")) } }

      it "adds new version entry" do
        run_task
        expect(versions_json["2026.1"]).to eq(
          {
            "developmentStartDate" => "2025-12-28",
            "releaseDate" => "2026-01",
            "supportEndDate" => "2026-09",
            "released" => false,
            "esr" => true,
            "supported" => true,
          },
        )
      end

      it "marks previous version as released" do
        run_task
        expect(versions_json["2025.12"]).to include(
          "released" => true,
          "releaseDate" => "2025-12-28",
        )
      end
    end
  end

  describe "release:stage_security_fixes" do
    subject(:run_task) do
      Dir.chdir(local_path) do
        capture_stdout { invoke_rake_task("release:stage_security_fixes", "main") }
      end
    end

    let(:origin_main_commits) do
      Dir.chdir(origin_path) { git("log", "--pretty=%s", "main").lines.map(&:strip) }
    end

    def origin_file(path)
      Dir.chdir(origin_path) { git("show", "main:#{path}") }
    end

    before do
      ENV["SECURITY_FIX_REFS"] = "origin/security-fix-one,origin/security-fix-two"
      Dir.chdir(origin_path) do
        git "checkout", "-b", "security-fix-one"
        File.write("firstfile.txt", "contents")
        git "add", "firstfile.txt"
        git "-c", "commit.gpgsign=false", "commit", "-m", "security fix one, commit one"
        File.write("secondfile.txt", "contents")
        git "add", "secondfile.txt"
        git "-c", "commit.gpgsign=false", "commit", "-m", "security fix one, commit two"
        git "checkout", "main"
        git "checkout", "-b", "security-fix-two"
        File.write("somefile.txt", "contents")
        git "add", "somefile.txt"
        git "-c", "commit.gpgsign=false", "commit", "-m", "security fix two"
      end
      run_task
    end

    after { ENV.delete("SECURITY_FIX_REFS") }

    it "cherry-picks all security fix commits in order" do
      expect(origin_main_commits).to eq(
        [
          "DEV: Bump development branch to v2025.12.0-latest.1",
          "security fix two",
          "security fix one, commit two",
          "security fix one, commit one",
          "Initial commit",
        ],
      )
    end

    it "includes files from all security fixes" do
      expect(origin_file("firstfile.txt")).to eq("contents")
      expect(origin_file("secondfile.txt")).to eq("contents")
      expect(origin_file("somefile.txt")).to eq("contents")
    end

    it "bumps the development version" do
      expect(origin_file("lib/version.rb")).to include('STRING = "2025.12.0-latest.1"')
    end
  end
end
