# frozen_string_literal: true

RSpec.describe "plugin rake tasks" do
  def clone_repo(repo_dir)
    clone_root = Dir.mktmpdir
    clone_path = File.join(clone_root, "plugin")
    Discourse::Utils.execute_command("git", "clone", "-q", repo_dir, clone_path)
    { clone_root: clone_root, clone_path: clone_path }
  end

  def run_git(repo_dir, *args)
    system("git", "-C", repo_dir, *args, exception: true)
  end

  def remote_ref_exists?(repo_dir, ref)
    system("git", "-C", repo_dir, "show-ref", "--verify", "--quiet", ref)
  end

  def cleanup_tmp_repo(path)
    FileUtils.remove_entry(path) if path && File.exist?(path)
  end

  describe "plugin:update" do
    let(:compat_branch) { "d-compat/#{Discourse::VERSION::MAJOR}.#{Discourse::VERSION::MINOR}" }
    let(:origin_repo) { setup_git_repo("plugin.rb" => "# v1") }
    let(:clone_setup) { clone_repo(origin_repo) }
    let(:plugin_repo) { clone_setup[:clone_path] }

    after do
      cleanup_tmp_repo(origin_repo)
      cleanup_tmp_repo(clone_setup[:clone_root])
    end

    it "updates even when stale remote refs conflict with d-compat branch namespaces" do
      run_git(origin_repo, "checkout", "-q", "-b", "d-compat")
      add_to_git_repo(origin_repo, "compat.txt" => "# legacy compat branch")
      run_git(origin_repo, "checkout", "-q", "main")

      expect(remote_ref_exists?(plugin_repo, "refs/remotes/origin/d-compat")).to eq(true)

      add_to_git_repo(origin_repo, "plugin.rb" => "# v2")
      run_git(origin_repo, "branch", "-q", "-D", "d-compat")
      run_git(origin_repo, "checkout", "-q", "-b", compat_branch)
      add_to_git_repo(origin_repo, "compat.txt" => "# namespaced compat branch")
      run_git(origin_repo, "checkout", "-q", "main")

      expect { invoke_rake_task("plugin:update", plugin_repo) }.not_to raise_error
      expect(File.read("#{plugin_repo}/plugin.rb")).to eq("# v2")
      expect(remote_ref_exists?(plugin_repo, "refs/remotes/origin/#{compat_branch}")).to eq(true)
      expect(remote_ref_exists?(plugin_repo, "refs/remotes/origin/d-compat")).to eq(false)
    end
  end
end
