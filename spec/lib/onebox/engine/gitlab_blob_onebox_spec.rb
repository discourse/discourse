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
end
