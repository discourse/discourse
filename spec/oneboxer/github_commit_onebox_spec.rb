# encoding: utf-8

require 'spec_helper'
require 'oneboxer'
require 'oneboxer/github_commit_onebox'

describe Oneboxer::GithubCommitOnebox do
  before(:each) do
    @o = Oneboxer::GithubCommitOnebox.new("https://github.com/discourse/discourse/commit/ee76f1926defa8309b3a7ea64a25707519529a13")
    FakeWeb.register_uri(:get, @o.translate_url, response: fixture_file('oneboxer/github_commit_onebox.response'))
  end

  it "translates the URL" do
    @o.translate_url.should == "https://api.github.com/repos/discourse/discourse/commits/ee76f1926defa8309b3a7ea64a25707519529a13"
  end
end
