require 'spec_helper'

describe ColorSchemeColor do
  def test_invalid_hex(hex)
    c = described_class.new(hex: hex)
    c.should_not be_valid
    c.errors[:hex].should be_present
  end

  it "validates hex value" do
    ['fff', 'ffffff', '333333', '333', '0BeeF0'].each do |hex|
      described_class.new(hex: hex).should be_valid
    end
    ['fffff', 'ffff', 'ff', 'f', '00000', '00', 'cheese', '#666666', '#666', '555 666'].each do |hex|
      test_invalid_hex(hex)
    end
  end
end
