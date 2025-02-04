# frozen_string_literal: true

RSpec.describe Onebox::Engine::GitlabBlobOnebox do
  before do
    @link =
      "https://gitlab.com/discourse/onebox/blob/master/lib/onebox/engine/gitlab_blob_onebox.rb"

    stub_request(
      :get,
      "https://gitlab.com/discourse/onebox/raw/master/lib/onebox/engine/gitlab_blob_onebox.rb",
    ).to_return(status: 200, body: onebox_response(described_class.onebox_name))
  end

  include_context "with engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes file name" do
      expect(html).to include("gitlab_blob_onebox.rb")
    end

    it "includes blob contents" do
      expect(html).to include("module Onebox")
    end
  end

  describe ".===" do
    it "matches valid GitLab blob URL" do
      valid_url = URI("https://gitlab.com/group/project/-/blob/main/file.txt")
      expect(described_class === valid_url).to eq(true)
    end

    it "matches valid GitLab blob URL with www" do
      valid_url_with_www = URI("https://www.gitlab.com/group/project/-/blob/main/file.txt")
      expect(described_class === valid_url_with_www).to eq(true)
    end

    it "does not match URL with extra domain" do
      malicious_url = URI("https://gitlab.com.malicious.com/group/project/-/blob/main/file.txt")
      expect(described_class === malicious_url).to eq(false)
    end

    it "does not match URL with subdomain" do
      subdomain_url = URI("https://sub.gitlab.com/group/project/-/blob/main/file.txt")
      expect(described_class === subdomain_url).to eq(false)
    end

    it "does not match URL with invalid path" do
      invalid_path_url = URI("https://gitlab.com/group/project/-/tree/main")
      expect(described_class === invalid_path_url).to eq(false)
    end
  end
end
