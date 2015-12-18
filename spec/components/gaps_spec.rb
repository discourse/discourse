require 'rails_helper'
require 'cache'

describe Gaps do


  it 'returns no gaps for empty data' do
    expect(Gaps.new(nil, nil)).to be_blank
  end

  it 'returns no gaps with one element' do
    expect(Gaps.new([1], [1])).to be_blank
  end

  it 'returns no gaps when all elements are present' do
    expect(Gaps.new([1,2,3], [1,2,3])).to be_blank
  end

  context "single element gap" do
    let(:gap) { Gaps.new([1,3], [1,2,3]) }

    it 'has a gap for post 3' do
      expect(gap).not_to be_blank
      expect(gap.before[3]).to eq([2])
      expect(gap.after).to be_blank
    end
  end

  context "larger gap" do
    let(:gap) { Gaps.new([1,2,3,6,7], [1,2,3,4,5,6,7]) }

    it 'has a gap for post 6' do
      expect(gap).not_to be_blank
      expect(gap.before[6]).to eq([4,5])
      expect(gap.after).to be_blank
    end
  end

  context "multiple gaps" do
    let(:gap) { Gaps.new([1,5,6,7,10], [1,2,3,4,5,6,7,8,9,10]) }

    it 'has both gaps' do
      expect(gap).not_to be_blank
      expect(gap.before[5]).to eq([2,3,4])
      expect(gap.before[10]).to eq([8,9])
      expect(gap.after).to be_blank
    end
  end

  context "a gap in the beginning" do
    let(:gap) { Gaps.new([2,3,4], [1,2,3,4]) }

    it 'has the gap' do
      expect(gap).not_to be_blank
      expect(gap.before[2]).to eq([1])
      expect(gap.after).to be_blank
    end
  end

  context "a gap in the ending" do
    let(:gap) { Gaps.new([1,2,3], [1,2,3,4]) }

    it 'has the gap' do
      expect(gap).not_to be_blank
      expect(gap.before).to be_blank
      expect(gap.after[3]).to eq([4])
    end
  end

  context "a large gap in the ending" do
    let(:gap) { Gaps.new([1,2,3], [1,2,3,4,5,6]) }

    it 'has the gap' do
      expect(gap).not_to be_blank
      expect(gap.before).to be_blank
      expect(gap.after[3]).to eq([4,5,6])
    end
  end


end
