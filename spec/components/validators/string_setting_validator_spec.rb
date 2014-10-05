require 'spec_helper'

describe StringSettingValidator do

  describe '#valid_value?' do
    shared_examples "for all StringSettingValidator opts" do
      it "returns true for blank values" do
        validator.valid_value?('').should == true
        validator.valid_value?(nil).should == true
      end
    end

    context 'with a regex' do
      subject(:validator) { described_class.new(regex: 'bacon') }

      include_examples "for all StringSettingValidator opts"

      it "returns true if value matches the regex" do
        validator.valid_value?('The bacon is delicious').should == true
      end

      it "returns false if the value doesn't match the regex" do
        validator.valid_value?('The vegetables are delicious').should == false
      end

      it "test some other regexes" do
        v = described_class.new(regex: '^(chocolate|banana)$')
        v.valid_value?('chocolate').should == true
        v.valid_value?('chocolates').should == false

        v = described_class.new(regex: '^[\w]+$')
        v.valid_value?('the_file').should == true
        v.valid_value?('the_file.bat').should == false
      end
    end

    context 'with min' do
      subject(:validator) { described_class.new(min: 2) }

      include_examples "for all StringSettingValidator opts"

      it "returns true if length is ok" do
        validator.valid_value?('ok').should == true
        validator.valid_value?('yep long enough').should == true
      end

      it "returns false if too short" do
        validator.valid_value?('x').should == false
      end
    end

    context 'with max' do
      subject(:validator) { described_class.new(max: 5) }

      include_examples "for all StringSettingValidator opts"

      it "returns true if length is ok" do
        validator.valid_value?('Z').should == true
        validator.valid_value?('abcde').should == true
      end

      it "returns false if too long" do
        validator.valid_value?('banana').should == false
      end
    end

    context 'combinations of options' do
      it "min and regex" do
        v = described_class.new(regex: '^[\w]+$', min: 3)
        v.valid_value?('chocolate').should == true
        v.valid_value?('hi').should == false
        v.valid_value?('game.exe').should == false
      end

      it "max and regex" do
        v = described_class.new(regex: '^[\w]+$', max: 5)
        v.valid_value?('chocolate').should == false
        v.valid_value?('a_b_c').should == true
        v.valid_value?('a b c').should == false
      end

      it "min and max" do
        v = described_class.new(min: 3, max: 5)
        v.valid_value?('chocolate').should == false
        v.valid_value?('a').should == false
        v.valid_value?('a b c').should == true
        v.valid_value?('a b').should == true
      end

      it "min, max, and regex" do
        v = described_class.new(min: 3, max: 12, regex: 'bacon')
        v.valid_value?('go bacon!').should == true
        v.valid_value?('sprinkle bacon on your cereal').should == false
        v.valid_value?('ba').should == false
      end
    end

  end

end
