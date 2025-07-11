# frozen_string_literal: true

require "rails_helper"

describe Jobs::ReplaceGithubNonPermalinks do
  let(:job) { described_class.new }
  let(:github_url) do
    "https://github.com/test/onebox/blob/master/lib/onebox/engine/github_blob_onebox.rb"
  end
  let(:github_permanent_url) do
    "https://github.com/test/onebox/blob/815ea9c0a8ffebe7bd7fcd34c10ff28c7a6b6974/lib/onebox/engine/github_blob_onebox.rb"
  end
  let(:github_url2) { "https://github.com/test/discourse/blob/master/app/models/tag.rb#L1-L3" }
  let(:github_permanent_url2) do
    "https://github.com/test/discourse/blob/7e4edcfae8a3c0e664b836ee7c5f28b47853a2f8/app/models/tag.rb#L1-L3"
  end
  let(:broken_github_url) do
    "https://github.com/test/oneblob/blob/master/lib/onebox/engine/nonexistent.rb"
  end
  let(:github_response_body) { { sha: "815ea9c0a8ffebe7bd7fcd34c10ff28c7a6b6974", commit: {} } }
  let(:github_response_body2) { { sha: "7e4edcfae8a3c0e664b836ee7c5f28b47853a2f8", commit: {} } }

  before do
    stub_request(:get, "https://api.github.com/repos/test/onebox/commits/master").to_return(
      status: 200,
      body: github_response_body.to_json,
      headers: {
      },
    )
    stub_request(
      :get,
      "https://api.github.com/repos/test/onebox/commits/815ea9c0a8ffebe7bd7fcd34c10ff28c7a6b6974",
    ).to_return(status: 200, body: github_response_body.to_json, headers: {})
    stub_request(:get, "https://api.github.com/repos/test/oneblob/commits/master").to_return(
      status: 404,
    )
    stub_request(:get, "https://api.github.com/repos/test/discourse/commits/master").to_return(
      status: 200,
      body: github_response_body2.to_json,
      headers: {
      },
    )
  end

  describe "#execute" do
    before do
      Jobs.run_immediately!
      SiteSetting.github_permalinks_enabled = true
    end

    it "replaces link with permanent link" do
      stub_request(:head, github_permanent_url).to_return(status: 200, body: "", headers: {})
      stub_request(
        :get,
        "https://raw.githubusercontent.com/test/onebox/815ea9c0a8ffebe7bd7fcd34c10ff28c7a6b6974/lib/onebox/engine/github_blob_onebox.rb",
      ).to_return(status: 200, body: "", headers: {})

      post = Fabricate(:post, raw: github_url)
      job.execute(post_id: post.id)
      post.reload

      expect(post.raw).to eq(github_permanent_url)
    end

    it "doesn't replace the link if it's already permanent" do
      post = Fabricate(:post, raw: github_permanent_url)
      job.execute(post_id: post.id)
      post.reload

      expect(post.raw).to eq(github_permanent_url)
    end

    it "doesn't change the post if link is broken" do
      post = Fabricate(:post, raw: broken_github_url)
      job.execute(post_id: post.id)
      post.reload

      expect(post.raw).to eq(broken_github_url)
    end

    it "works with multiple github urls in the post" do
      stub_request(:get, github_permanent_url).to_return(status: 200, body: "")
      stub_request(:get, github_permanent_url2.gsub(/#.+$/, "")).to_return(status: 200, body: "")
      post = Fabricate(:post, raw: "#{github_url} #{github_url2} htts://github.com")
      job.execute(post_id: post.id)
      post.reload

      updated_post = "#{github_permanent_url} #{github_permanent_url2} htts://github.com"
      expect(post.raw).to eq(updated_post)
    end
  end

  describe "#excluded?" do
    before do
      SiteSetting.github_permalinks_exclude =
        "README.md|discourse/discourse/directory/file.rb|discourse/onebox/docs/*|discourse/anotherRepo/*|someUser/*"
    end

    it "returns true when it should be excluded" do
      expect(job.excluded?("discourse", "discourse", "README.md")).to be true
      expect(job.excluded?("discourse", "discourse", "directory/file.rb")).to be true
      expect(job.excluded?("discourse", "onebox", "docs/file.rb")).to be true
      expect(job.excluded?("discourse", "anotherRepo", "directory/file.rb")).to be true
      expect(job.excluded?("someUser", "someRepo", "file.rb")).to be true
    end

    it "return false when url should be replaced" do
      expect(job.excluded?("discourse", "discourse", "directory/file2.rb")).to be false
      expect(job.excluded?("discourse", "onebox", "directory/file.rb")).to be false
      expect(job.excluded?("discourse", "discourse", "directory/included.rb")).to be false
    end
  end
end
