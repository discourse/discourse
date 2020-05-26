# frozen_string_literal: true

require 'rails_helper'

describe FastImage do
  let(:svg_file) do
    StringIO.new(<<~SVG)
      <svg width="100" height="100">
        <circle cx="50" cy="50" r="40" stroke="green" stroke-width="4" fill="yellow" />
      </svg>
    SVG
  end

  let(:xml_file) do
    StringIO.new(<<~XML)
      <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body>
          <foo />
        </soap:Body>
      </soap:Envelope>
    XML
  end

  it "correctly detects SVG" do
    expect(FastImage.new(svg_file).type).to eq(:svg)
  end

  it "doesn't detect XML starting with <s as SVG" do
    expect(FastImage.new(xml_file).type).to be_nil
  end

  it "still needs to be monkey patched" do
    expect(FastImage.new(xml_file).original_type).to eq(:svg), <<~MESSAGE
      The fast_image monkey patch isn't needed anymore.
      Please remove the following files:
        * lib/freedom_patches/fast_image.rb
        * spec/components/freedom_patches/fast_image_spec.rb
    MESSAGE
  end
end
