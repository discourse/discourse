# frozen_string_literal: true

RSpec.describe RemoteImage do
  describe ".size_and_animated" do
    def stub_image(fixture)
      url = "https://example.com/#{fixture}"
      stub_request(:get, url).to_return(status: 200, body: file_from_fixtures(fixture).read)
      url
    end

    # mimics FinalDestination#get streaming a response in chunks until told to stop
    def stream_in_chunks(fixture, chunk_size, then_raise: nil)
      chunks = file_from_fixtures(fixture).read.b.scan(/.{1,#{chunk_size}}/m)
      destination = Object.new
      destination.define_singleton_method(:get) do |&block|
        completed =
          chunks.all? do |chunk|
            catch(:done) do
              block.call(nil, chunk, nil)
              true
            end
          end
        raise then_raise if completed && then_raise
      end
      FinalDestination.stubs(:new).returns(destination)
      "https://example.com/#{fixture}"
    end

    it "reads the size and animation of animated images" do
      expect(described_class.size_and_animated(stub_image("animated.gif"))).to eq(
        [[320, 320], true],
      )
      expect(described_class.size_and_animated(stub_image("animated.webp"))).to eq(
        [[250, 250], true],
      )
    end

    it "returns a nil animated flag for formats that can't be animated" do
      expect(described_class.size_and_animated(stub_image("logo.jpg"))).to eq([[512, 512], nil])
    end

    it "reads static images whose stream ends between two parses" do
      url = stream_in_chunks("static.gif", 1)

      expect(described_class.size_and_animated(url)).to eq([[2, 1], false])
    end

    it "stops reading past the maximum image size or duration" do
      url = stream_in_chunks("animated.gif", 256)

      SiteSetting.max_image_size_kb = 1
      expect(described_class.size_and_animated(url)).to eq([[320, 320], nil])

      SiteSetting.max_image_size_kb = 10_240
      stub_const(FinalDestination, "MAX_REQUEST_TIME_SECONDS", -1) do
        expect(described_class.size_and_animated(url)).to eq([[320, 320], nil])
      end
    end

    it "keeps what was read before the connection dropped" do
      url = stream_in_chunks("static.gif", 40, then_raise: EOFError)

      expect(described_class.size_and_animated(url)).to eq([[2, 1], false])
    end

    it "returns nils when the image can't be fetched" do
      stub_request(:get, "https://example.com/missing.gif").to_return(status: 404)
      stub_request(:get, "https://example.com/refused.gif").to_raise(Errno::ECONNREFUSED)
      too_long = "https://example.com/#{"a" * UrlHelper::MAX_URL_LENGTH}.gif"

      expect(described_class.size_and_animated("https://example.com/missing.gif")).to eq([nil, nil])
      expect(described_class.size_and_animated("https://example.com/refused.gif")).to eq([nil, nil])
      expect(described_class.size_and_animated(too_long)).to eq([nil, nil])
    end

    it "doesn't swallow unexpected errors" do
      url = stub_image("animated.gif")
      FastImage.stubs(:new).raises(NoMethodError)

      expect { described_class.size_and_animated(url) }.to raise_error(NoMethodError)
    end

    it "stops reading responses that aren't images" do
      url = "https://example.com/page"
      stub_request(:get, url).to_return(status: 200, body: "<html>#{"a" * 2.kilobytes}</html>")

      expect(described_class.size_and_animated(url)).to eq([nil, nil])
    end
  end
end
