# frozen_string_literal: true

require "rails_helper"

describe Onebox::Engine::GithubBlobOnebox do
  before do
    @link = "https://github.com/discourse/onebox/blob/master/lib/onebox/engine/github_blob_onebox.rb"
    @uri = URI.parse(@link)
    stub_request(:get, "https://raw.githubusercontent.com/discourse/onebox/master/lib/onebox/engine/github_blob_onebox.rb")
      .to_return(status: 200, body: onebox_response(described_class.onebox_name))
  end

  include_context "engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes file name" do
      expect(html).to include("github_blob_onebox.rb")
    end

    it "includes blob contents" do
      expect(html).to include("module Oneboxer")
    end

    it "does not include blob contents if it is binary" do
      # stub_request if the response must be binary (ASCII-8BIT)
      uri = mock('object')
      uri.stubs(:open).returns(File.open("#{Rails.root}/spec/fixtures/pdf/small.pdf", "rb"))
      URI.stubs(:parse).with(@link).returns(@uri)
      URI.stubs(:parse).with('https://raw.githubusercontent.com/discourse/onebox/master/lib/onebox/engine/github_blob_onebox.rb').returns(uri)

      expect(html).not_to include('/Pages')
      expect(html).to include('This file is binary.')
    end
  end
end
