require 'rails_helper'

describe StringSettingValidator do

  describe '#valid_value?' do
    shared_examples "for all StringSettingValidator opts" do
      it "returns true for blank values" do
        expect(validator.valid_value?('')).to eq(true)
        expect(validator.valid_value?(nil)).to eq(true)
      end
    end

    context 'with a regex' do
      subject(:validator) { described_class.new(regex: 'bacon') }

      include_examples "for all StringSettingValidator opts"

      it "returns true if value matches the regex" do
        expect(validator.valid_value?('The bacon is delicious')).to eq(true)
      end

      it "returns false if the value doesn't match the regex" do
        expect(validator.valid_value?('The vegetables are delicious')).to eq(false)
      end

      it "test some other regexes" do
        v = described_class.new(regex: '^(chocolate|banana)$')
        expect(v.valid_value?('chocolate')).to eq(true)
        expect(v.valid_value?('chocolates')).to eq(false)

        v = described_class.new(regex: '^[\w]+$')
        expect(v.valid_value?('the_file')).to eq(true)
        expect(v.valid_value?('the_file.bat')).to eq(false)
      end
    end

    context 'with min' do
      subject(:validator) { described_class.new(min: 2) }

      include_examples "for all StringSettingValidator opts"

      it "returns true if length is ok" do
        expect(validator.valid_value?('ok')).to eq(true)
        expect(validator.valid_value?('yep long enough')).to eq(true)
      end

      it "returns false if too short" do
        expect(validator.valid_value?('x')).to eq(false)
      end
    end

    context 'with max' do
      subject(:validator) { described_class.new(max: 5) }

      include_examples "for all StringSettingValidator opts"

      it "returns true if length is ok" do
        expect(validator.valid_value?('Z')).to eq(true)
        expect(validator.valid_value?('abcde')).to eq(true)
      end

      it "returns false if too long" do
        expect(validator.valid_value?('banana')).to eq(false)
      end
    end

    context 'combinations of options' do
      it "min and regex" do
        v = described_class.new(regex: '^[\w]+$', min: 3)
        expect(v.valid_value?('chocolate')).to eq(true)
        expect(v.valid_value?('hi')).to eq(false)
        expect(v.valid_value?('game.exe')).to eq(false)
      end

      it "max and regex" do
        v = described_class.new(regex: '^[\w]+$', max: 5)
        expect(v.valid_value?('chocolate')).to eq(false)
        expect(v.valid_value?('a_b_c')).to eq(true)
        expect(v.valid_value?('a b c')).to eq(false)
      end

      it "min and max" do
        v = described_class.new(min: 3, max: 5)
        expect(v.valid_value?('chocolate')).to eq(false)
        expect(v.valid_value?('a')).to eq(false)
        expect(v.valid_value?('a b c')).to eq(true)
        expect(v.valid_value?('a b')).to eq(true)
      end

      it "min, max, and regex" do
        v = described_class.new(min: 3, max: 12, regex: 'bacon')
        expect(v.valid_value?('go bacon!')).to eq(true)
        expect(v.valid_value?('sprinkle bacon on your cereal')).to eq(false)
        expect(v.valid_value?('ba')).to eq(false)
      end
    end

  end

end
