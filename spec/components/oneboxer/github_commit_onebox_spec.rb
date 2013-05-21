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

  it "generates the expected onebox for GitHub Commit" do
    @o.onebox.should == expected_github_commit_result
  end

private
  def expected_github_commit_result
    <<EXPECTED
<div class="onebox-result">
    <div class="source">
      <div class="info">
        <a href="https://github.com/discourse/discourse/commit/ee76f1926defa8309b3a7ea64a25707519529a13" class="track-link" target="_blank">
          <img class="favicon" src="/assets/favicons/github.png"> github.com
        </a>
      </div>
    </div>
  <div class="onebox-result-body">
    <a href="https://github.com/eviltrout" target="_blank"><img alt="eviltrout" src="https://secure.gravatar.com/avatar/c6e17f2ae2a215e87ff9e878a4e63cd9?d=https://a248.e.akamai.net/assets.github.com%2Fimages%2Fgravatars%2Fgravatar-user-420.png"></a>
    <h4><a href="https://github.com/eviltrout" target="_blank">eviltrout</a></h4>
    Debugging Tool for Hot Topics
    <div class="github-commit-stats">Changed <strong>16 files</strong> with <strong>245 additions</strong> and <strong>43 deletions</strong>.</div>
    <div class="date">
      <a href="https://github.com/discourse/discourse/commit/ee76f1926defa8309b3a7ea64a25707519529a13" target="_blank">08:52PM - 02 Apr 13</a>
    </div>
  </div>
  <div class="clearfix"></div>
</div>
EXPECTED
  end
end
