require 'spec_helper'
require 'image_sizer'

describe ImageSizer do

  before do
    SiteSetting.expects(:max_image_width).returns(500)
  end

  it 'returns the same dimensions if the width is less than the maximum' do
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

  describe 'when larger than the maximum' do

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

end
