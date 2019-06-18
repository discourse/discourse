# frozen_string_literal: true

require 'rails_helper'

describe ColorSchemeColor do
  after do
    ColorScheme.hex_cache.clear
  end

  def test_invalid_hex(hex)
    c = described_class.new(hex: hex)
    expect(c).not_to be_valid
    expect(c.errors[:hex]).to be_present
  end

  it "validates hex value" do
    ['fff', 'ffffff', '333333', '333', '0BeeF0'].each do |hex|
      expect(described_class.new(hex: hex)).to be_valid
    end
    ['fffff', 'ffff', 'ff', 'f', '00000', '00', 'cheese', '#666666', '#666', '555 666'].each do |hex|
      test_invalid_hex(hex)
    end
  end
end
