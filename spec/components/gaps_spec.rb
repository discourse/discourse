require 'spec_helper'
require 'cache'

describe Gaps do


  it 'returns no gaps for empty data' do
    Gaps.new(nil, nil).should be_blank
  end

  it 'returns no gaps with one element' do
    Gaps.new([1], [1]).should be_blank
  end

  it 'returns no gaps when all elements are present' do
    Gaps.new([1,2,3], [1,2,3]).should be_blank
  end

  context "single element gap" do
    let(:gap) { Gaps.new([1,3], [1,2,3]) }

    it 'has a gap for post 3' do
      gap.should_not be_blank
      gap.before[3].should == [2]
      gap.after.should be_blank
    end
  end

  context "larger gap" do
    let(:gap) { Gaps.new([1,2,3,6,7], [1,2,3,4,5,6,7]) }

    it 'has a gap for post 6' do
      gap.should_not be_blank
      gap.before[6].should == [4,5]
      gap.after.should be_blank
    end
  end

  context "multiple gaps" do
    let(:gap) { Gaps.new([1,5,6,7,10], [1,2,3,4,5,6,7,8,9,10]) }

    it 'has both gaps' do
      gap.should_not be_blank
      gap.before[5].should == [2,3,4]
      gap.before[10].should == [8,9]
      gap.after.should be_blank
    end
  end

  context "a gap in the beginning" do
    let(:gap) { Gaps.new([2,3,4], [1,2,3,4]) }

    it 'has the gap' do
      gap.should_not be_blank
      gap.before[2].should == [1]
      gap.after.should be_blank
    end
  end

  context "a gap in the ending" do
    let(:gap) { Gaps.new([1,2,3], [1,2,3,4]) }

    it 'has the gap' do
      gap.should_not be_blank
      gap.before.should be_blank
      gap.after[3].should == [4]
    end
  end

  context "a large gap in the ending" do
    let(:gap) { Gaps.new([1,2,3], [1,2,3,4,5,6]) }

    it 'has the gap' do
      gap.should_not be_blank
      gap.before.should be_blank
      gap.after[3].should == [4,5,6]
    end
  end


end
