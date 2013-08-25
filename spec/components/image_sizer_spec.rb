require 'spec_helper'
require 'image_sizer'

describe ImageSizer do

  before do
    SiteSetting.stubs(:max_image_width).returns(500)
    SiteSetting.stubs(:max_image_height).returns(500)
  end

  it 'returns the same dimensions when smaller than the maximums' do
    ImageSizer.resize(400, 200).should == [400, 200]
  end

  it 'returns nil if the width is nil' do
    ImageSizer.resize(nil, 100).should be_nil
  end

  it 'returns nil if the height is nil' do
    ImageSizer.resize(100, nil).should be_nil
  end

  it 'works with string parameters' do
    ImageSizer.resize('100', '101').should == [100, 101]
  end

  describe 'when larger than the maximum width' do

    before do
      @w, @h = ImageSizer.resize(600, 123)
    end

    it 'returns the maxmimum width if larger than the maximum' do
      @w.should == 500
    end

    it 'resizes the height retaining the aspect ratio' do
      @h.should == 102
    end

  end

  describe 'when larger than the maximum height' do

    before do
      @w, @h = ImageSizer.resize(123, 600)
    end

    it 'returns the maxmimum height if larger than the maximum' do
      @h.should == 500
    end

    it 'resizes the width retaining the aspect ratio' do
      @w.should == 102
    end

  end

  describe 'when larger than the maximums' do

    before do
      @w, @h = ImageSizer.resize(533, 800)
    end

    it 'resizes both dimensions retaining the aspect ratio' do
      @h.should == 500
      @w.should == 333
    end

  end

end
