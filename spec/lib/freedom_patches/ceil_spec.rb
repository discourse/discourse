require 'rails_helper'

describe Float do
  describe '#ceil' do
    it 'works correctly' do
      expect(1.2.ceil).to eq(2)
      expect(2.0.ceil).to eq(2)
      expect((-1.2).ceil).to eq(-1)
      expect((-2.0).ceil).to eq(-2)

      expect(1.234567.ceil(2)).to eq(1.24)
      expect(1.234567.ceil(3)).to eq(1.235)
      expect(1.234567.ceil(4)).to eq(1.2346)
      expect(1.234567.ceil(5)).to eq(1.23457)

      expect(34567.89.ceil(-5)).to eq(100000)
      expect(34567.89.ceil(-4)).to eq(40000)
      expect(34567.89.ceil(-3)).to eq(35000)
      expect(34567.89.ceil(-2)).to eq(34600)
      expect(34567.89.ceil(-1)).to eq(34570)
      expect(34567.89.ceil(0)).to eq(34568)
      expect(34567.89.ceil(1)).to eq(34567.9)
      expect(34567.89.ceil(2)).to eq(34567.89)
      expect(34567.89.ceil(3)).to eq(34567.89)
    end
  end
end

describe Integer do
  describe '#ceil' do
    it 'works correctly' do
      expect(1.ceil).to eq(1)
      expect(1.ceil(2)).to eq(1.0)
      expect(15.ceil(-1)).to eq(20)
    end
  end
end
