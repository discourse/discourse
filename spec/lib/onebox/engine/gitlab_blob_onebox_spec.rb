# frozen_string_literal: true

require "spec_helper"

describe Onebox::Engine::GitlabBlobOnebox do
  before(:all) do
    @link = "https://gitlab.com/discourse/onebox/blob/master/lib/onebox/engine/gitlab_blob_onebox.rb"
    fake("https://gitlab.com/discourse/onebox/raw/master/lib/onebox/engine/gitlab_blob_onebox.rb", response(described_class.onebox_name))
    puts described_class.onebox_name
  end

  include_context "engines"
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
