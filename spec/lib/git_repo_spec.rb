# frozen_string_literal: true

RSpec.describe GitRepo do
  let(:git_repo) { GitRepo.new("/tmp", "discourse") }

  it "returns the correct URL" do
    Discourse::Utils.stubs(:execute_command).returns("https://github.com/username/my_plugin.git")
    expect(git_repo.url).to eq("https://github.com/username/my_plugin")
    Discourse::Utils.stubs(:execute_command).returns("git@github.com/username/my_plugin.git")
    expect(git_repo.url).to eq("https://github.com/username/my_plugin")
  end

  it "returns the correct commit hash" do
    Discourse::Utils.expects(:execute_command).returns("123456")
    expect(git_repo.latest_local_commit).to eq("123456")
  end
end
