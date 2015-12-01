require 'rails_helper'
require 'image_sizer'

describe ImageSizer do

  before do
    SiteSetting.stubs(:max_image_width).returns(500)
    SiteSetting.stubs(:max_image_height).returns(500)
  end

  it 'returns the same dimensions when smaller than the maximums' do
    expect(ImageSizer.resize(400, 200)).to eq([400, 200])
  end

  it 'returns nil if the width is nil' do
    expect(ImageSizer.resize(nil, 100)).to eq(nil)
  end

  it 'returns nil if the height is nil' do
    expect(ImageSizer.resize(100, nil)).to eq(nil)
  end

  it 'works with string parameters' do
    expect(ImageSizer.resize('100', '101')).to eq([100, 101])
  end

  describe 'when larger than the maximum width' do

    before do
      @w, @h = ImageSizer.resize(600, 123)
    end

    it 'returns the maxmimum width if larger than the maximum' do
      expect(@w).to eq(500)
    end

    it 'resizes the height retaining the aspect ratio' do
      expect(@h).to eq(102)
    end

  end

  describe 'when larger than the maximum height' do

    before do
      @w, @h = ImageSizer.resize(123, 600)
    end

    it 'returns the maxmimum height if larger than the maximum' do
      expect(@h).to eq(500)
    end

    it 'resizes the width retaining the aspect ratio' do
      expect(@w).to eq(102)
    end

  end

  describe 'when larger than the maximums' do

    before do
      @w, @h = ImageSizer.resize(533, 800)
    end

    it 'resizes both dimensions retaining the aspect ratio' do
      expect(@h).to eq(500)
      expect(@w).to eq(333)
    end

  end

end
