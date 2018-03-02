require 'rails_helper'
require 'file_helper'

describe FileHelper do

  let(:url) { "https://eviltrout.com/trout.png" }
  let(:png) { Base64.decode64("R0lGODlhAQABALMAAAAAAIAAAACAAICAAAAAgIAAgACAgMDAwICAgP8AAAD/AP//AAAA//8A/wD//wBiZCH5BAEAAA8ALAAAAAABAAEAAAQC8EUAOw==") }

  before do
    stub_request(:any, /https:\/\/eviltrout.com/)
    stub_request(:get, url).to_return(body: png)
  end

  describe "download" do

    it "correctly raises an OpenURI HTTP error if it gets a 404 even with redirect" do
      url = "http://fourohfour.com/404"
      stub_request(:get, url).to_return(status: 404, body: "404")

      expect do
        begin
          FileHelper.download(
            url,
            max_file_size: 10000,
            tmp_file_name: 'trouttmp',
            follow_redirect: true
          )
        rescue => e
          expect(e.io.status[0]).to eq("404")
          raise
        end
      end.to raise_error(OpenURI::HTTPError)
    end

    it "correctly raises an OpenURI HTTP error if it gets a 404" do
      url = "http://fourohfour.com/404"

      stub_request(:get, url).to_return(status: 404, body: "404")

      expect do
        begin
          FileHelper.download(
            url,
            max_file_size: 10000,
            tmp_file_name: 'trouttmp',
            follow_redirect: false
          )
        rescue => e
          expect(e.io.status[0]).to eq("404")
          raise
        end
      end.to raise_error(OpenURI::HTTPError)
    end

    it "returns a file with the image" do
      tmpfile = FileHelper.download(
        url,
        max_file_size: 10000,
        tmp_file_name: 'trouttmp'
      )
      expect(tmpfile.read[0..5]).to eq("GIF89a")
    end

    it "works with a protocol relative url" do
      tmpfile = FileHelper.download(
        "//eviltrout.com/trout.png",
        max_file_size: 10000,
        tmp_file_name: 'trouttmp'
      )
      expect(tmpfile.read[0..5]).to eq("GIF89a")
    end
  end

end
