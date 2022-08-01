# frozen_string_literal: true

require "onebox/oembed"

RSpec.describe Onebox::Oembed do
  it "excludes text tags" do
    json = '{"text": "<iframe src=\'https://ifram.es/foo/bar\'></iframe>"}'
    oembed = described_class.new(json)
    expect(oembed.text).to be_nil
  end

  it "includes html tags" do
    json = '{"html": "<iframe src=\'https://ifram.es/foo/bar\'></iframe>"}'
    oembed = described_class.new(json)
    expect(oembed.html).to eq("<iframe src='https://ifram.es/foo/bar'></iframe>")
  end
end
