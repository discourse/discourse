# frozen_string_literal: true

require "file_helper"

RSpec.describe FileHelper do
  let(:url) { "https://eviltrout.com/trout.png" }
  let(:png) { File.read("#{Rails.root}/spec/fixtures/images/cropped.png") }

  before do
    stub_request(:any, %r{https://eviltrout.com})
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
            max_file_size: 10_000,
            tmp_file_name: "trouttmp",
            follow_redirect: true,
          )
        rescue => e
          expect(e.io.status[0]).to eq("404")
          raise
        end
      end.to raise_error(OpenURI::HTTPError, "404 Error")
    end

    it "does not follow redirects if instructed not to" do
      url2 = "https://test.com/image.png"
      stub_request(:get, url).to_return(status: 302, body: "", headers: { location: url2 })

      missing =
        FileHelper.download(
          url,
          max_file_size: 10_000,
          tmp_file_name: "trouttmp",
          follow_redirect: false,
        )

      expect(missing).to eq(nil)
    end

    it "does follow redirects if instructed to" do
      url2 = "https://test.com/image.png"
      stub_request(:get, url).to_return(status: 302, body: "", headers: { location: url2 })
      stub_request(:get, url2).to_return(status: 200, body: "i am the body")

      begin
        found =
          FileHelper.download(
            url,
            max_file_size: 10_000,
            tmp_file_name: "trouttmp",
            follow_redirect: true,
          )

        expect(found.read).to eq("i am the body")
      ensure
        found&.close
        found&.unlink
      end
    end

    it "correctly raises an OpenURI HTTP error if it gets a 404" do
      url = "http://fourohfour.com/404"

      stub_request(:get, url).to_return(status: 404, body: "404")

      expect do
        begin
          FileHelper.download(
            url,
            max_file_size: 10_000,
            tmp_file_name: "trouttmp",
            follow_redirect: false,
          )
        rescue => e
          expect(e.io.status[0]).to eq("404")
          raise
        end
      end.to raise_error(OpenURI::HTTPError)
    end

    it "returns a file with the image" do
      begin
        tmpfile = FileHelper.download(url, max_file_size: 10_000, tmp_file_name: "trouttmp")

        expect(Base64.encode64(tmpfile.read)).to eq(Base64.encode64(png))
      ensure
        tmpfile&.close
        tmpfile&.unlink
      end
    end

    it "works with a protocol relative url" do
      begin
        tmpfile =
          FileHelper.download(
            "//eviltrout.com/trout.png",
            max_file_size: 10_000,
            tmp_file_name: "trouttmp",
          )

        expect(Base64.encode64(tmpfile.read)).to eq(Base64.encode64(png))
      ensure
        tmpfile&.close
        tmpfile&.unlink
      end
    end

    describe "when max_file_size is exceeded" do
      it "should return nil" do
        tmpfile =
          FileHelper.download(
            "//eviltrout.com/trout.png",
            max_file_size: 1,
            tmp_file_name: "trouttmp",
          )

        expect(tmpfile).to eq(nil)
      end

      it "is able to retain the tmpfile" do
        begin
          tmpfile =
            FileHelper.download(
              "//eviltrout.com/trout.png",
              max_file_size: 1,
              tmp_file_name: "trouttmp",
              retain_on_max_file_size_exceeded: true,
            )

          expect(tmpfile.closed?).to eq(false)
        ensure
          tmpfile&.close
          tmpfile&.unlink
        end
      end
    end

    describe "when url is a jpeg" do
      let(:url) { "https://eviltrout.com/trout.jpg" }

      it "should prioritize the content type returned by the response" do
        begin
          stub_request(:get, url).to_return(body: png, headers: { "content-type": "image/png" })

          tmpfile = FileHelper.download(url, max_file_size: 10_000, tmp_file_name: "trouttmp")

          expect(File.extname(tmpfile)).to eq(".png")
        ensure
          tmpfile&.close
          tmpfile&.unlink
        end
      end
    end
  end

  describe "inline safety checks" do
    describe ".is_inline_safe?" do
      it "returns true for non-SVG images" do
        expect(FileHelper.is_inline_safe?("image.png")).to eq(true)
        expect(FileHelper.is_inline_safe?("photo.jpg")).to eq(true)
        expect(FileHelper.is_inline_safe?("photo.jpeg")).to eq(true)
        expect(FileHelper.is_inline_safe?("image.gif")).to eq(true)
        expect(FileHelper.is_inline_safe?("picture.webp")).to eq(true)
        expect(FileHelper.is_inline_safe?("pic.avif")).to eq(true)
        expect(FileHelper.is_inline_safe?("icon.ico")).to eq(true)
      end

      it "returns true for PDFs" do
        expect(FileHelper.is_inline_safe?("document.pdf")).to eq(true)
        expect(FileHelper.is_inline_safe?("DOCUMENT.PDF")).to eq(true)
      end

      it "returns true for video files" do
        expect(FileHelper.is_inline_safe?("video.mp4")).to eq(true)
        expect(FileHelper.is_inline_safe?("movie.webm")).to eq(true)
        expect(FileHelper.is_inline_safe?("clip.mov")).to eq(true)
        expect(FileHelper.is_inline_safe?("VIDEO.AVI")).to eq(true)
      end

      it "returns true for audio files" do
        expect(FileHelper.is_inline_safe?("song.mp3")).to eq(true)
        expect(FileHelper.is_inline_safe?("audio.ogg")).to eq(true)
        expect(FileHelper.is_inline_safe?("podcast.m4a")).to eq(true)
        expect(FileHelper.is_inline_safe?("MUSIC.WAV")).to eq(true)
      end

      it "returns false for SVG" do
        expect(FileHelper.is_inline_safe?("image.svg")).to eq(false)
        expect(FileHelper.is_inline_safe?("IMAGE.SVG")).to eq(false)
      end

      it "returns false for HTML files" do
        expect(FileHelper.is_inline_safe?("page.html")).to eq(false)
        expect(FileHelper.is_inline_safe?("page.htm")).to eq(false)
      end

      it "returns false for XML files" do
        expect(FileHelper.is_inline_safe?("data.xml")).to eq(false)
      end

      it "returns false for text files" do
        expect(FileHelper.is_inline_safe?("readme.txt")).to eq(false)
      end

      it "returns false for JavaScript files" do
        expect(FileHelper.is_inline_safe?("script.js")).to eq(false)
      end
    end

    describe ".inline_safe_files" do
      it "includes non-SVG images" do
        safe_files = FileHelper.inline_safe_files
        expect(safe_files).to include("png", "jpg", "jpeg", "gif", "webp", "avif", "ico")
      end

      it "includes PDF" do
        expect(FileHelper.inline_safe_files).to include("pdf")
      end

      it "includes video files" do
        safe_files = FileHelper.inline_safe_files
        expect(safe_files).to include("mp4", "webm", "mov", "avi")
      end

      it "includes audio files" do
        safe_files = FileHelper.inline_safe_files
        expect(safe_files).to include("mp3", "ogg", "m4a", "wav")
      end

      it "excludes SVG" do
        expect(FileHelper.inline_safe_files).not_to include("svg")
      end
    end
  end
end
