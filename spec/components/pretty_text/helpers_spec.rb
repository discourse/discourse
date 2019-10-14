# frozen_string_literal: true

require 'rails_helper'

describe PrettyText::Helpers do

  context "lookup_upload_urls" do
    let(:upload) { Fabricate(:upload) }

    it "should return cdn url if available" do
      short_url = upload.short_url
      result = PrettyText::Helpers.lookup_upload_urls([short_url])
      expect(result[short_url][:url]).to eq(upload.url)

      set_cdn_url "https://awesome.com"

      result = PrettyText::Helpers.lookup_upload_urls([short_url])
      expect(result[short_url][:url]).to eq("https://awesome.com#{upload.url}")
    end
  end

end
