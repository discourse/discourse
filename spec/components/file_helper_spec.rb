require 'rails_helper'
require 'file_helper'

describe FileHelper do

  let(:url) { "https://eviltrout.com/trout.png" }
  let(:png) { File.read("#{Rails.root}/spec/fixtures/images/cropped.png") }

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
      end.to raise_error(OpenURI::HTTPError, "404 Error: 404")
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
      begin
        tmpfile = FileHelper.download(
          url,
          max_file_size: 10000,
          tmp_file_name: 'trouttmp'
        )

        expect(Base64.encode64(tmpfile.read)).to eq(Base64.encode64(png))
      ensure
        tmpfile&.close
      end
    end

    it "works with a protocol relative url" do
      begin
        tmpfile = FileHelper.download(
          "//eviltrout.com/trout.png",
          max_file_size: 10000,
          tmp_file_name: 'trouttmp'
        )

        expect(Base64.encode64(tmpfile.read)).to eq(Base64.encode64(png))
      ensure
        tmpfile&.close
      end
    end

    describe 'when max_file_size is exceeded' do
      it 'should return nil' do
        tmpfile = FileHelper.download(
          "//eviltrout.com/trout.png",
          max_file_size: 1,
          tmp_file_name: 'trouttmp'
        )

        expect(tmpfile).to eq(nil)
      end

      it 'is able to retain the tmpfile' do
        begin
          tmpfile = FileHelper.download(
            "//eviltrout.com/trout.png",
            max_file_size: 1,
            tmp_file_name: 'trouttmp',
            retain_on_max_file_size_exceeded: true
          )

          expect(tmpfile.closed?).to eq(false)
        ensure
          tmpfile&.close
        end
      end
    end

    describe 'when url is a jpeg' do
      let(:url) { "https://eviltrout.com/trout.jpg" }

      it "should prioritize the content type returned by the response" do
        begin
          stub_request(:get, url).to_return(body: png, headers: {
            "content-type": "image/png"
          })

          tmpfile = FileHelper.download(
            url,
            max_file_size: 10000,
            tmp_file_name: 'trouttmp'
          )

          expect(File.extname(tmpfile)).to eq('.png')
        ensure
          tmpfile&.close
        end
      end
    end
  end

end
