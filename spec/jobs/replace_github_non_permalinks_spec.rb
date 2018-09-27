require 'rails_helper'
require 'jobs/regular/pull_hotlinked_images'

describe Jobs::ReplaceGithubNonPermalinks do
  let(:github_url) { "https://github.com/test/onebox/blob/master/lib/onebox/engine/github_blob_onebox.rb" }
  let(:github_permanent_url) { "https://github.com/test/onebox/blob/815ea9c0a8ffebe7bd7fcd34c10ff28c7a6b6974/lib/onebox/engine/github_blob_onebox.rb" }
  let(:broken_github_url) { "https://github.com/test/oneblob/blob/master/lib/onebox/engine/nonexistent.rb" }
  let(:github_response_body) { { sha: '815ea9c0a8ffebe7bd7fcd34c10ff28c7a6b6974', commit: {} } }

  before do
    stub_request(:get, "https://api.github.com/repos/test/onebox/commits/master")
      .to_return(status: 200, body: github_response_body.to_json, headers: {})
    stub_request(:get, "https://api.github.com/repos/test/onebox/commits/815ea9c0a8ffebe7bd7fcd34c10ff28c7a6b6974")
      .to_return(status: 200, body: github_response_body.to_json, headers: {})
    stub_request(:get, "https://api.github.com/repos/test/oneblob/commits/master").to_return(status: 404)
  end

  describe '#execute' do
    before do
      SiteSetting.queue_jobs = false
      SiteSetting.onebox_domains_blacklist = "github.com"
    end

    it 'replaces link with permanent link' do
      post = Fabricate(:post, raw: "#{github_url}")
      Jobs::ReplaceGithubNonPermalinks.new.execute(post_id: post.id)
      post.reload

      expect(post.raw).to eq(github_permanent_url)
    end

    it "doesn't replace the link if it's already permanent" do
      post = Fabricate(:post, raw: github_permanent_url)
      Jobs::ReplaceGithubNonPermalinks.new.execute(post_id: post.id)
      post.reload

      expect(post.raw).to eq(github_permanent_url)
    end

    it "doesn't change the post if link is broken" do
      post = Fabricate(:post, raw: broken_github_url)
      Jobs::ReplaceGithubNonPermalinks.new.execute(post_id: post.id)
      post.reload

      expect(post.raw).to eq(broken_github_url)
    end
  end
end
